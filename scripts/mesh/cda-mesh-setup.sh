#!/bin/sh
set -eu

MESH_IFACE="${MESH_IFACE:-wlan0}"
MESH_ID="${MESH_ID:-CDA-Mesh}"
BAT_IFACE="${BAT_IFACE:-bat0}"
MESH_CHANNEL="${MESH_CHANNEL:-2412}"

log() {
  printf '[cda-mesh] %s\n' "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "comando ausente: $1" >&2
    exit 1
  }
}

node_octet() {
  if [ -r /etc/machine-id ]; then
    hash="$(sha256sum /etc/machine-id | awk '{print $1}')"
    octet_hex="$(printf '%s' "$hash" | cut -c1-2)"
    echo $((16#$octet_hex % 200 + 20))
  else
    echo 250
  fi
}

main() {
  require_cmd ip
  require_cmd iw
  require_cmd modprobe

  modprobe batman-adv

  ip link show "$BAT_IFACE" >/dev/null 2>&1 || ip link add name "$BAT_IFACE" type batadv

  ip link set "$MESH_IFACE" down || true
  iw dev "$MESH_IFACE" set type mp
  ip link set "$MESH_IFACE" up
  iw dev "$MESH_IFACE" mesh join "$MESH_ID" freq "$MESH_CHANNEL"

  ip link set dev "$MESH_IFACE" master "$BAT_IFACE"

  node_ip="10.42.0.$(node_octet)/24"
  ip addr add "$node_ip" dev "$BAT_IFACE" 2>/dev/null || true
  ip link set "$BAT_IFACE" up

  log "mesh ativa em $MESH_IFACE -> $BAT_IFACE ($MESH_ID, $node_ip)"
}

main "$@"
