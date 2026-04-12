#!/bin/sh
set -eu

PATH=/sbin:/bin:/usr/sbin:/usr/bin
RUNTIME_CDA_DIR="${CDA_RUNTIME_DIR:-/run/cda}"

log() {
  printf '[init-overlay] %s\n' "$*" >&2
}

panic() {
  printf '[init-overlay][panic] %s\n' "$*" >&2
  exec sh
}

cmdline_get() {
  key="$1"
  for arg in $(cmdline_words); do
    case "$arg" in
      "$key"=*)
        printf '%s\n' "${arg#*=}"
        return 0
        ;;
    esac
  done
  return 1
}

cmdline_words() {
  if [ -n "${CDA_CMDLINE:-}" ]; then
    printf '%s\n' "$CDA_CMDLINE"
  else
    cat /proc/cmdline
  fi
}

mount_api_fs() {
  mkdir -p /proc /sys /dev
  mount -t proc proc /proc 2>/dev/null || true
  mount -t sysfs sys /sys 2>/dev/null || true
  mount -t devtmpfs dev /dev 2>/dev/null || true
  mount -t tmpfs tmpfs /run 2>/dev/null || true
}

find_mem_available_bytes() {
  value="$(awk '/^MemAvailable:/ { print $2; found=1; exit } END { if (!found) print 0 }' /proc/meminfo)"
  [ "$value" -gt 0 ] || value="$(awk '/^MemTotal:/ { print $2; found=1; exit } END { if (!found) print 0 }' /proc/meminfo)"
  echo $((value * 1024))
}

sum_squashfs_bytes() {
  total=0
  for img in "$1"/*.squashfs; do
    [ -f "$img" ] || continue
    size="$(stat -c '%s' "$img" 2>/dev/null || echo 0)"
    total=$((total + size))
  done
  echo "$total"
}

load_deployment_descriptor() {
  deployment_root="$1"
  deployment_name="$2"
  descriptor="$deployment_root/deployment.conf"

  DEPLOYMENT_NAME="$deployment_name"
  DEPLOYMENT_VERSION="unknown"
  DEPLOYMENT_IMAGE_DIR="images"
  DEPLOYMENT_SLOT="$deployment_name"

  if [ -r "$descriptor" ]; then
    . "$descriptor"
  fi

  [ -n "${DEPLOYMENT_NAME:-}" ] || DEPLOYMENT_NAME="$deployment_name"
  [ -n "${DEPLOYMENT_VERSION:-}" ] || DEPLOYMENT_VERSION="unknown"
  [ -n "${DEPLOYMENT_IMAGE_DIR:-}" ] || DEPLOYMENT_IMAGE_DIR="images"
  DEPLOYMENT_SLOT="$deployment_name"
}

resolve_deployment_source() {
  deployment_dir="$(cmdline_get cda.deployment_dir || true)"
  [ -n "$deployment_dir" ] || return 1

  deployment_name="$(cmdline_get cda.deployment || true)"
  [ -n "$deployment_name" ] || deployment_name=current

  deployment_root="$deployment_dir/$deployment_name"
  [ -d "$deployment_root" ] || return 1

  load_deployment_descriptor "$deployment_root" "$deployment_name"

  for candidate in \
    "$deployment_root/$DEPLOYMENT_IMAGE_DIR" \
    "$deployment_root/images" \
    "$deployment_root/bootlayers" \
    "$deployment_root"; do
    [ -d "$candidate" ] || continue
    DEPLOYMENT_SOURCE="$candidate"
    printf '%s\n' "$candidate"
    return 0
  done

  return 1
}

mount_boot_source() {
  mkdir -p "$RUNTIME_CDA_DIR/boot"

  if resolve_deployment_source >/dev/null 2>&1; then
    source_dir="$DEPLOYMENT_SOURCE"
    log "deployment selecionado: ${DEPLOYMENT_NAME:-current} (${DEPLOYMENT_VERSION:-unknown})"
    printf '%s\n' "$source_dir"
    return 0
  fi

  source_dir="$(cmdline_get cda.squashdir || true)"
  if [ -n "$source_dir" ] && [ -d "$source_dir" ]; then
    echo "$source_dir"
    return 0
  fi

  root_dev="$(cmdline_get root || true)"
  live_dev="$(cmdline_get cda.live_dev || true)"

  for dev in "$live_dev" "$root_dev"; do
    [ -n "$dev" ] || continue
    if mount -o ro "$dev" "$RUNTIME_CDA_DIR/boot" 2>/dev/null; then
      inner="$(cmdline_get cda.squash_subdir || true)"
      if [ -n "$inner" ] && [ -d "$RUNTIME_CDA_DIR/boot/$inner" ]; then
        echo "$RUNTIME_CDA_DIR/boot/$inner"
      else
        echo "$RUNTIME_CDA_DIR/boot"
      fi
      return 0
    fi
  done

  panic "não foi possível montar o dispositivo com os arquivos .squashfs"
}

write_runtime_metadata() {
  [ -n "${DEPLOYMENT_NAME:-}" ] || return 0

  echo "$DEPLOYMENT_NAME" > "$RUNTIME_CDA_DIR/deployment-name"
  echo "${DEPLOYMENT_VERSION:-unknown}" > "$RUNTIME_CDA_DIR/deployment-version"
  echo "${DEPLOYMENT_SLOT:-$DEPLOYMENT_NAME}" > "$RUNTIME_CDA_DIR/deployment-slot"
  [ -n "${DEPLOYMENT_SOURCE:-}" ] && echo "$DEPLOYMENT_SOURCE" > "$RUNTIME_CDA_DIR/deployment-source"
}

copy_images_to_ram() {
  src_dir="$1"
  total_bytes="$2"
  mkdir -p "$RUNTIME_CDA_DIR/images"
  overhead=$((256 * 1024 * 1024))
  size=$((total_bytes + overhead))
  mount -t tmpfs -o "size=$size" tmpfs "$RUNTIME_CDA_DIR/images"
  for img in "$src_dir"/*.squashfs; do
    [ -f "$img" ] || continue
    cp -f "$img" "$RUNTIME_CDA_DIR/images/"
  done
  echo "$RUNTIME_CDA_DIR/images"
}

mount_lower_layers() {
  src_dir="$1"
  mkdir -p "$RUNTIME_CDA_DIR/lower"
  i=0
  lowerdir=""

  for img in "$src_dir"/*.squashfs; do
    [ -f "$img" ] || continue
    i=$((i + 1))
    layer="$RUNTIME_CDA_DIR/lower/$i"
    mkdir -p "$layer"
    mount -t squashfs -o loop,ro "$img" "$layer"
    if [ -z "$lowerdir" ]; then
      lowerdir="$layer"
    else
      lowerdir="$layer:$lowerdir"
    fi
  done

  [ "$i" -gt 0 ] || panic "nenhuma imagem .squashfs encontrada"
  echo "$lowerdir"
}

mount_overlay_root() {
  lowerdir="$1"
  mkdir -p /sysroot "$RUNTIME_CDA_DIR/rw"
  mount -t tmpfs tmpfs "$RUNTIME_CDA_DIR/rw"
  mkdir -p "$RUNTIME_CDA_DIR/rw/upper" "$RUNTIME_CDA_DIR/rw/work"
  mount -t overlay overlay -o "lowerdir=$lowerdir,upperdir=$RUNTIME_CDA_DIR/rw/upper,workdir=$RUNTIME_CDA_DIR/rw/work" /sysroot
}

switch_to_real_root() {
  mkdir -p /sysroot/run/cda
  for meta in boot-mode deployment-name deployment-version deployment-slot deployment-source; do
    if [ -r "$RUNTIME_CDA_DIR/$meta" ]; then
      cp "$RUNTIME_CDA_DIR/$meta" "/sysroot/run/cda/$meta" 2>/dev/null || true
    fi
  done
  mount --move /run /sysroot/run || true
  exec switch_root /sysroot /sbin/init
}

main() {
  mount_api_fs
  mkdir -p "$RUNTIME_CDA_DIR"

  # Tenta habilitar suporte de kernel quando compilado como modulo.
  # Em kernels com suporte built-in, essas chamadas apenas falham silenciosamente.
  modprobe loop 2>/dev/null || true
  modprobe squashfs 2>/dev/null || true
  modprobe overlay 2>/dev/null || true

  ram_min_mib="$(cmdline_get cda.ram_min_mib || true)"
  [ -n "$ram_min_mib" ] || ram_min_mib=4096

  force_disk="$(cmdline_get cda.force_disk || true)"
  force_ram="$(cmdline_get cda.force_ram || true)"

  boot_source_file="$RUNTIME_CDA_DIR/boot-source"
  mount_boot_source > "$boot_source_file"
  squash_source="$(cat "$boot_source_file")"
  total_squash_bytes="$(sum_squashfs_bytes "$squash_source")"
  mem_available_bytes="$(find_mem_available_bytes)"
  mem_available_mib=$((mem_available_bytes / 1024 / 1024))

  mode="disk"
  if [ "$force_disk" = "1" ]; then
    mode="disk"
  elif [ "$force_ram" = "1" ]; then
    mode="ram"
  # Política de dois gatilhos:
  # 1) piso absoluto de RAM (cda.ram_min_mib) para evitar boots em RAM marginal;
  # 2) pelo menos 2x o tamanho total dos squashfs para cópia + folga operacional.
  elif [ "$mem_available_mib" -ge "$ram_min_mib" ] && [ "$mem_available_bytes" -ge $((total_squash_bytes * 2)) ]; then
    mode="ram"
  fi

  log "modo de boot: $mode (MemAvailable=${mem_available_mib}MiB, squashfs=$((total_squash_bytes / 1024 / 1024))MiB)"
  echo "$mode" > "$RUNTIME_CDA_DIR/boot-mode"
  write_runtime_metadata

  if [ "$mode" = "ram" ]; then
    lower_source="$(copy_images_to_ram "$squash_source" "$total_squash_bytes")"
  else
    lower_source="$squash_source"
  fi

  lowerdir="$(mount_lower_layers "$lower_source")"
  mount_overlay_root "$lowerdir"
  switch_to_real_root
}

if [ "${CDA_INIT_OVERLAY_LIB_ONLY:-0}" != 1 ]; then
  main "$@"
fi
