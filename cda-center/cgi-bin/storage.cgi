#!/bin/sh
# CGI: Storage and filesystem — reads from df, mount, /run/cda
printf 'Content-Type: application/json\r\n\r\n'

# Mount points via /proc/mounts
mounts=""
first_mount=1
while IFS=' ' read -r device mountpoint fstype options _ _; do
  # Skip pseudo-filesystems except the ones we care about
  case "$fstype" in
    proc|sysfs|devpts|securityfs|cgroup*|pstore|bpf|debugfs|tracefs|configfs|fusectl|hugetlbfs|mqueue|rpc_pipefs|autofs)
      continue ;;
  esac
  device_esc="$(echo "$device" | sed 's/"/\\"/g')"
  mountpoint_esc="$(echo "$mountpoint" | sed 's/"/\\"/g')"
  options_esc="$(echo "$options" | sed 's/"/\\"/g' | head -c 200)"

  [ "$first_mount" = 1 ] && first_mount=0 || mounts="$mounts,"
  mounts="$mounts{\"device\":\"$device_esc\",\"mountpoint\":\"$mountpoint_esc\",\"fstype\":\"$fstype\",\"options\":\"$options_esc\"}"
done < /proc/mounts

# Disk usage via df
disk_usage=""
first_df=1
df -k 2>/dev/null | tail -n +2 | while IFS= read -r line; do
  fs="$(echo "$line" | awk '{print $1}')"
  size_kb="$(echo "$line" | awk '{print $2}')"
  used_kb="$(echo "$line" | awk '{print $3}')"
  avail_kb="$(echo "$line" | awk '{print $4}')"
  pct="$(echo "$line" | awk '{gsub(/%/,"",$5); print $5}')"
  mp="$(echo "$line" | awk '{print $6}')"

  # Format sizes
  if [ "$size_kb" -ge 1048576 ] 2>/dev/null; then
    size_fmt="$((size_kb / 1048576))G"
  elif [ "$size_kb" -ge 1024 ] 2>/dev/null; then
    size_fmt="$((size_kb / 1024))M"
  else
    size_fmt="${size_kb}K"
  fi
  if [ "$used_kb" -ge 1048576 ] 2>/dev/null; then
    used_fmt="$((used_kb / 1048576))G"
  elif [ "$used_kb" -ge 1024 ] 2>/dev/null; then
    used_fmt="$((used_kb / 1024))M"
  else
    used_fmt="${used_kb}K"
  fi

  fs_esc="$(echo "$fs" | sed 's/"/\\"/g')"
  mp_esc="$(echo "$mp" | sed 's/"/\\"/g')"

  [ "$first_df" = 1 ] && first_df=0 || printf ','
  printf '{"filesystem":"%s","mountpoint":"%s","size":"%s","used":"%s","size_kb":%s,"used_kb":%s,"avail_kb":%s,"pct":%s}' \
    "$fs_esc" "$mp_esc" "$size_fmt" "$used_fmt" "${size_kb:-0}" "${used_kb:-0}" "${avail_kb:-0}" "${pct:-0}"
done > /tmp/cda_df.json 2>/dev/null
disk_usage="$(cat /tmp/cda_df.json 2>/dev/null)"
rm -f /tmp/cda_df.json

# Overlay info
overlay_info=""
overlay_mount="$(grep 'type overlay' /proc/mounts 2>/dev/null | head -1)"
if [ -n "$overlay_mount" ]; then
  overlay_opts="$(echo "$overlay_mount" | awk '{print $4}')"
  lower="$(echo "$overlay_opts" | grep -o 'lowerdir=[^,]*' | sed 's/lowerdir=//')"
  upper="$(echo "$overlay_opts" | grep -o 'upperdir=[^,]*' | sed 's/upperdir=//')"
  work="$(echo "$overlay_opts" | grep -o 'workdir=[^,]*' | sed 's/workdir=//')"

  # Count squashfs layers
  layers=0
  for l in $(echo "$lower" | tr ':' ' '); do
    layers=$((layers + 1))
  done

  # Upper usage
  upper_used_kb=0
  if [ -d "$upper" ]; then
    upper_used_kb=$(du -sk "$upper" 2>/dev/null | awk '{print $1}')
  fi

  overlay_info="{\"lowerdir\":\"$lower\",\"upperdir\":\"$upper\",\"workdir\":\"$work\",\"layers\":$layers,\"upper_used_kb\":${upper_used_kb:-0}}"
fi

# Block devices (lsblk-like from /sys/block)
blocks=""
first_blk=1
for blk_dir in /sys/block/*; do
  name="$(basename "$blk_dir")"
  case "$name" in loop*|ram*) continue ;; esac
  size_sectors="$(cat "$blk_dir/size" 2>/dev/null || echo 0)"
  size_bytes=$((size_sectors * 512))
  ro="$(cat "$blk_dir/ro" 2>/dev/null || echo 0)"
  removable="$(cat "$blk_dir/removable" 2>/dev/null || echo 0)"

  if [ "$size_bytes" -ge 1073741824 ] 2>/dev/null; then
    size_fmt="$((size_bytes / 1073741824))G"
  elif [ "$size_bytes" -ge 1048576 ] 2>/dev/null; then
    size_fmt="$((size_bytes / 1048576))M"
  else
    size_fmt="${size_bytes}B"
  fi

  [ "$first_blk" = 1 ] && first_blk=0 || blocks="$blocks,"
  blocks="$blocks{\"name\":\"$name\",\"size\":\"$size_fmt\",\"size_bytes\":$size_bytes,\"ro\":$ro,\"removable\":$removable}"
done

cat <<JSON
{
  "mounts": [$mounts],
  "disk_usage": [$disk_usage],
  "overlay": ${overlay_info:-null},
  "block_devices": [$blocks]
}
JSON
