#!/bin/sh
set -eu

WORKDIR="${WORKDIR:-/tmp/cda-mesh-lab}"
BASE_DISK="${BASE_DISK:?defina BASE_DISK com a imagem qcow2 base}"
KERNEL_IMAGE="${KERNEL_IMAGE:?defina KERNEL_IMAGE}" 
INITRD_IMAGE="${INITRD_IMAGE:?defina INITRD_IMAGE}"
SSH_USER="${SSH_USER:-student}"
SSH_KEY="${SSH_KEY:?defina SSH_KEY com chave privada para acesso SSH}"

VM_COUNT=4
RAM_LIST="8192 8192 8192 2048"
SSH_PORTS="2201 2202 2203 2204"
MCAST_ADDR="230.10.10.10"
MCAST_PORT="24567"

mkdir -p "$WORKDIR"

ssh_cmd() {
  vm="$1"
  shift
  eval "port=\$(echo $SSH_PORTS | awk '{print \$$vm}')"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$port" "$SSH_USER@127.0.0.1" "$@"
}

start_vm() {
  vm="$1"
  eval "ram=\$(echo $RAM_LIST | awk '{print \$$vm}')"
  eval "port=\$(echo $SSH_PORTS | awk '{print \$$vm}')"

  disk="$WORKDIR/vm${vm}.qcow2"
  qemu-img create -f qcow2 -F qcow2 -b "$BASE_DISK" "$disk" >/dev/null

  qemu-system-x86_64 \
    -name "cda-vm${vm}" \
    -m "$ram" \
    -smp 2 \
    -kernel "$KERNEL_IMAGE" \
    -initrd "$INITRD_IMAGE" \
    -append "console=ttyS0 cda.ram_min_mib=4096" \
    -drive "if=virtio,file=$disk,format=qcow2" \
    -netdev "socket,id=mesh0,mcast=${MCAST_ADDR}:${MCAST_PORT}" \
    -device virtio-net-pci,netdev=mesh0 \
    -netdev "user,id=mgmt0,hostfwd=tcp::${port}-:22" \
    -device virtio-net-pci,netdev=mgmt0 \
    -nographic >"$WORKDIR/vm${vm}.log" 2>&1 &

  echo $! > "$WORKDIR/vm${vm}.pid"
}

wait_for_ssh() {
  vm="$1"
  tries=60
  while [ "$tries" -gt 0 ]; do
    if ssh_cmd "$vm" 'echo ok' >/dev/null 2>&1; then
      return 0
    fi
    tries=$((tries - 1))
    sleep 2
  done
  return 1
}

assert_boot_media_policy() {
  for vm in 1 2 3; do
    ssh_cmd "$vm" "df -h | grep -E 'tmpfs|overlay'"
    ssh_cmd "$vm" "cat /run/cda/boot-mode | grep -x ram"
  done
  ssh_cmd 4 "cat /run/cda/boot-mode | grep -x disk"
}

assert_mesh_failover_with_dask() {
  vm3_ip="$(ssh_cmd 3 "ip -4 -o addr show dev bat0 | awk '{print \$4}' | cut -d/ -f1" | tr -d '\r')"
  [ -n "$vm3_ip" ] || {
    echo "falha ao determinar o IP da VM-3 na interface bat0" >&2
    return 1
  }

  ssh_cmd 1 "sudo iptables -A OUTPUT -d $vm3_ip -j DROP"
  ssh_cmd 3 "nohup dask-scheduler --host $vm3_ip --port 8786 >/tmp/dask-scheduler.log 2>&1 &"
  ssh_cmd 1 "python3 - <<'PY'
from dask.distributed import Client
c = Client('tcp://$vm3_ip:8786')
future = c.submit(lambda x: x * 2, 21)
print(future.result(timeout=30))
PY"
}

cleanup() {
  for vm in 1 2 3 4; do
    if [ -f "$WORKDIR/vm${vm}.pid" ]; then
      kill "$(cat "$WORKDIR/vm${vm}.pid")" 2>/dev/null || true
    fi
  done
}

trap cleanup EXIT INT TERM

for vm in 1 2 3 4; do
  start_vm "$vm"
done

for vm in 1 2 3 4; do
  wait_for_ssh "$vm"
done

assert_boot_media_policy
assert_mesh_failover_with_dask

echo "[ok] laboratório de virtualização e malha homologado"
