#!/bin/sh
# CGI: Network interfaces + batman-adv mesh status
printf 'Content-Type: application/json\r\n\r\n'

# Collect all network interfaces
interfaces=""
first_iface=1
for iface_dir in /sys/class/net/*; do
  name="$(basename "$iface_dir")"
  state="$(cat "$iface_dir/operstate" 2>/dev/null || echo unknown)"
  mac="$(cat "$iface_dir/address" 2>/dev/null || echo 00:00:00:00:00:00)"
  mtu="$(cat "$iface_dir/mtu" 2>/dev/null || echo 0)"
  type_id="$(cat "$iface_dir/type" 2>/dev/null || echo 0)"

  # Get IP addresses via ip command
  ip_addr=""
  if command -v ip >/dev/null 2>&1; then
    ip_addr="$(ip -4 addr show "$name" 2>/dev/null | awk '/inet / {print $2}' | head -1)"
  fi

  # RX/TX bytes
  rx_bytes="$(cat "$iface_dir/statistics/rx_bytes" 2>/dev/null || echo 0)"
  tx_bytes="$(cat "$iface_dir/statistics/tx_bytes" 2>/dev/null || echo 0)"
  rx_packets="$(cat "$iface_dir/statistics/rx_packets" 2>/dev/null || echo 0)"
  tx_packets="$(cat "$iface_dir/statistics/tx_packets" 2>/dev/null || echo 0)"
  rx_errors="$(cat "$iface_dir/statistics/rx_errors" 2>/dev/null || echo 0)"
  tx_errors="$(cat "$iface_dir/statistics/tx_errors" 2>/dev/null || echo 0)"

  # Format bytes
  if [ "$rx_bytes" -ge 1073741824 ] 2>/dev/null; then
    rx_fmt="$((rx_bytes / 1073741824))G"
  elif [ "$rx_bytes" -ge 1048576 ] 2>/dev/null; then
    rx_fmt="$((rx_bytes / 1048576))M"
  elif [ "$rx_bytes" -ge 1024 ] 2>/dev/null; then
    rx_fmt="$((rx_bytes / 1024))K"
  else
    rx_fmt="${rx_bytes}B"
  fi
  if [ "$tx_bytes" -ge 1073741824 ] 2>/dev/null; then
    tx_fmt="$((tx_bytes / 1073741824))G"
  elif [ "$tx_bytes" -ge 1048576 ] 2>/dev/null; then
    tx_fmt="$((tx_bytes / 1048576))M"
  elif [ "$tx_bytes" -ge 1024 ] 2>/dev/null; then
    tx_fmt="$((tx_bytes / 1024))K"
  else
    tx_fmt="${tx_bytes}B"
  fi

  [ "$first_iface" = 1 ] && first_iface=0 || interfaces="$interfaces,"
  interfaces="$interfaces{\"name\":\"$name\",\"state\":\"$state\",\"mac\":\"$mac\",\"mtu\":$mtu,\"ip\":\"$ip_addr\",\"rx\":\"$rx_fmt\",\"tx\":\"$tx_fmt\",\"rx_bytes\":$rx_bytes,\"tx_bytes\":$tx_bytes,\"rx_packets\":$rx_packets,\"tx_packets\":$tx_packets,\"rx_errors\":$rx_errors,\"tx_errors\":$tx_errors}"
done

# Batman-adv originators (mesh peers)
mesh_peers=""
mesh_active=0
first_peer=1
if command -v batctl >/dev/null 2>&1; then
  bat_iface="${BAT_IFACE:-bat0}"
  batctl meshif "$bat_iface" originators 2>/dev/null | grep '^\s*\*' | while IFS= read -r line; do
    originator="$(echo "$line" | awk '{print $2}')"
    last_seen="$(echo "$line" | awk '{print $3}')"
    tq="$(echo "$line" | awk '{gsub(/[()]/,"",$4); print $4}')"
    nexthop="$(echo "$line" | awk '{print $5}')"
    outif="$(echo "$line" | awk '{gsub(/[\[\]]/,"",$6); print $6}')"
    [ "$first_peer" = 1 ] && first_peer=0 || printf ','
    printf '{"originator":"%s","last_seen":"%s","tq":%s,"nexthop":"%s","outif":"%s"}' \
      "$originator" "$last_seen" "${tq:-0}" "$nexthop" "$outif"
    mesh_active=$((mesh_active + 1))
  done > /tmp/cda_mesh_peers.json 2>/dev/null
  mesh_peers="$(cat /tmp/cda_mesh_peers.json 2>/dev/null)"
  rm -f /tmp/cda_mesh_peers.json
fi

# batman-adv gateway mode
gw_mode="unknown"
if command -v batctl >/dev/null 2>&1; then
  gw_mode="$(batctl meshif "${BAT_IFACE:-bat0}" gw_mode 2>/dev/null | awk '{print $1}')"
fi

# Routing table
routes=""
first_route=1
if command -v ip >/dev/null 2>&1; then
  ip route 2>/dev/null | while IFS= read -r line; do
    escaped="$(echo "$line" | sed 's/"/\\"/g')"
    [ "$first_route" = 1 ] && first_route=0 || printf ','
    printf '"%s"' "$escaped"
  done > /tmp/cda_routes.json 2>/dev/null
  routes="$(cat /tmp/cda_routes.json 2>/dev/null)"
  rm -f /tmp/cda_routes.json
fi

# DNS
dns=""
first_dns=1
if [ -r /etc/resolv.conf ]; then
  dns="$(awk '/^nameserver/ {print "\"" $2 "\""}' /etc/resolv.conf 2>/dev/null | paste -sd,)"
fi

cat <<JSON
{
  "interfaces": [$interfaces],
  "mesh": {
    "bat_iface": "${BAT_IFACE:-bat0}",
    "gw_mode": "$gw_mode",
    "peers": [$mesh_peers],
    "active_peers": $mesh_active
  },
  "routes": [${routes}],
  "dns": [${dns}]
}
JSON
