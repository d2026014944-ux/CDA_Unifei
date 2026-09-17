#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME_DIR="$ROOT_DIR/dist/runtime-vm"
WORK_DIR="$RUNTIME_DIR/work"
ROOTFS_DIR="$WORK_DIR/rootfs"
INITRAMFS_DIR="$WORK_DIR/initramfs"
BASE_SQUASH="$WORK_DIR/base.squashfs"
PID_FILE="$RUNTIME_DIR/qemu.pid"
LOG_FILE="$RUNTIME_DIR/qemu.log"
KERNEL_IMAGE="$RUNTIME_DIR/vmlinuz"
INITRD_IMAGE="$RUNTIME_DIR/initrd.img"

mkdir -p "$RUNTIME_DIR" "$WORK_DIR"
sudo rm -rf "$ROOTFS_DIR" "$INITRAMFS_DIR"
mkdir -p \
  "$ROOTFS_DIR/bin" \
  "$ROOTFS_DIR/sbin" \
  "$ROOTFS_DIR/proc" \
  "$ROOTFS_DIR/sys" \
  "$ROOTFS_DIR/dev" \
  "$ROOTFS_DIR/run" \
  "$ROOTFS_DIR/tmp" \
  "$ROOTFS_DIR/www" \
  "$ROOTFS_DIR/bootlayers"

cp /usr/bin/busybox "$ROOTFS_DIR/bin/busybox"
# Core applets + extras for CGI scripts (processes, network, storage, logs, exec)
APPS="sh mount mkdir cat echo sleep awk sort find stat cp ip httpd uname hostname basename grep head tail wc du tr sed paste cut getconf pidof sha256sum timeout dmesg df date printf kill ls ln chmod chown id modprobe depmod"
for app in $APPS; do
  ln -sf /bin/busybox "$ROOTFS_DIR/bin/$app"
done

# Copy CDA OS Control Center (real dashboard with CGI backend).
CDA_CENTER_DIR="$ROOT_DIR/cda-center"
if [ -d "$CDA_CENTER_DIR" ]; then
  cp -r "$CDA_CENTER_DIR"/* "$ROOTFS_DIR/www/"
  
  # Remove Windows CRLF (\r) line endings from CGI scripts!
  # Se o script tiver \r, o Linux (busybox httpd) vai falhar com "bad interpreter".
  for cgi in "$ROOTFS_DIR/www/cgi-bin/"*.cgi; do
    if [ -f "$cgi" ]; then
      sed -i 's/\r$//' "$cgi" 2>/dev/null || true
      chmod +x "$cgi"
    fi
  done
fi

cat > "$ROOTFS_DIR/sbin/init" <<'INIT'
#!/bin/sh
set -eu

mount -t proc proc /proc || true
mount -t sysfs sys /sys || true
mount -t devtmpfs dev /dev || true

# /run e movido do initramfs por switch_root; nao remonte para preservar /run/cda/boot-mode.
mkdir -p /run/cda /tmp
mount -t tmpfs tmpfs /tmp || true

MODE="unknown"
[ -r /run/cda/boot-mode ] && MODE="$(cat /run/cda/boot-mode)"
KERNEL="$(uname -r)"
DEPLOYMENT_NAME="current"
[ -r /run/cda/deployment-name ] && DEPLOYMENT_NAME="$(cat /run/cda/deployment-name)"
DEPLOYMENT_SLOT="current"
[ -r /run/cda/deployment-slot ] && DEPLOYMENT_SLOT="$(cat /run/cda/deployment-slot)"
DEPLOYMENT_VERSION="unknown"
[ -r /run/cda/deployment-version ] && DEPLOYMENT_VERSION="$(cat /run/cda/deployment-version)"

ip link set lo up || true
for netdev in /sys/class/net/*; do
  name="$(basename "$netdev")"
  [ "$name" = "lo" ] && continue
  ip link set "$name" up || true
  ip addr add 10.0.2.15/24 dev "$name" 2>/dev/null || true
  ip route add default via 10.0.2.2 dev "$name" 2>/dev/null || true
  break
done

# CDA OS Control Center: arquivos em /www/ já provisionados durante o build.
# CGI scripts em /www/cgi-bin/ leem dados reais de /proc, /sys, /run/cda, batctl, systemctl.
# Nenhum HTML inline necessário — o busybox httpd serve /www/ com suporte nativo a CGI.

echo "[init] BINDING HTTPD NA PORTA 8080 (Servindo CDA Center)..." > /dev/kmsg
exec /bin/httpd -f -p 8080 -h /www
INIT
chmod +x "$ROOTFS_DIR/sbin/init"

mksquashfs "$ROOTFS_DIR" "$BASE_SQUASH" -noappend -comp xz >/dev/null

STOCK_INITRD="$(ls /boot/initrd.img-* | sort | tail -n 1)"
KERNEL_VER="$(basename "$STOCK_INITRD" | sed 's/^initrd.img-//')"
sudo rm -rf "$INITRAMFS_DIR"
mkdir -p "$INITRAMFS_DIR"
sudo unmkinitramfs "$STOCK_INITRD" "$INITRAMFS_DIR/unpacked" >/dev/null
sudo chown -R "$(id -u)":"$(id -g)" "$INITRAMFS_DIR/unpacked"

if [ -d "$INITRAMFS_DIR/unpacked/main" ]; then
  INITRAMFS_MAIN="$INITRAMFS_DIR/unpacked/main"
else
  INITRAMFS_MAIN="$INITRAMFS_DIR/unpacked"
fi

cp "$ROOT_DIR/initramfs/init-overlay.sh" "$INITRAMFS_MAIN/init"
chmod +x "$INITRAMFS_MAIN/init"
mkdir -p "$INITRAMFS_MAIN/bootlayers"
cp "$BASE_SQUASH" "$INITRAMFS_MAIN/bootlayers/base.squashfs"
mkdir -p "$INITRAMFS_MAIN/bootlayers/deployments/base/images"
cp "$BASE_SQUASH" "$INITRAMFS_MAIN/bootlayers/deployments/base/images/base.squashfs"
cat > "$INITRAMFS_MAIN/bootlayers/deployments/base/deployment.conf" <<'EOF'
DEPLOYMENT_NAME=base
DEPLOYMENT_VERSION=local-vm
DEPLOYMENT_IMAGE_DIR=images
DEPLOYMENT_SLOT=base
EOF
ln -sfn base "$INITRAMFS_MAIN/bootlayers/deployments/current"

for module_path in \
  "/lib/modules/$KERNEL_VER/kernel/fs/overlayfs/overlay.ko.zst" \
  "/lib/modules/$KERNEL_VER/kernel/fs/squashfs/squashfs.ko.zst" \
  "/lib/modules/$KERNEL_VER/kernel/drivers/block/loop.ko.zst"; do
  if [ -r "$module_path" ]; then
    relative_path="${module_path#/lib/modules/$KERNEL_VER/}"
    target_dir="$INITRAMFS_MAIN/usr/lib/modules/$KERNEL_VER/$(dirname "$relative_path")"
    mkdir -p "$target_dir"
    cp "$module_path" "$target_dir/"
  fi
done

depmod -b "$INITRAMFS_MAIN" "$KERNEL_VER" >/dev/null 2>&1 || true

(
  cd "$INITRAMFS_MAIN"
  find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "$RUNTIME_DIR/initramfs.cpio.gz"
)

if [ ! -r "$KERNEL_IMAGE" ]; then
  sudo install -m 0644 "$(ls /boot/vmlinuz-* | sort | tail -n 1)" "$KERNEL_IMAGE"
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  kill "$(cat "$PID_FILE")" || true
fi

qemu-system-x86_64 \
  -name cda-linux-os \
  -m 4096 \
  -smp 2 \
  -kernel "$KERNEL_IMAGE" \
  -initrd "$RUNTIME_DIR/initramfs.cpio.gz" \
  -append "console=ttyS0 cda.squashdir=/bootlayers cda.deployment_dir=/bootlayers/deployments cda.deployment=current cda.force_ram=1" \
  -nic user,model=virtio-net-pci,hostfwd=tcp:0.0.0.0:18080-:8080 \
  -nographic > "$LOG_FILE" 2>&1 &

echo $! > "$PID_FILE"

echo "[ok] VM iniciada"
echo "PID: $(cat "$PID_FILE")"
echo "Log: $LOG_FILE"
echo "Acesso: http://127.0.0.1:18080"
