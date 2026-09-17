#!/bin/sh
# CGI: Process list — reads from /proc/[pid]/ directories
printf 'Content-Type: application/json\r\n\r\n'

hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
uptime_sec=$(awk '{print $1}' /proc/uptime 2>/dev/null)
uptime_ticks=$(echo "$uptime_sec $hz" | awk '{printf "%.0f", $1 * $2}')
mem_total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
page_size_kb=$(($(getconf PAGESIZE 2>/dev/null || echo 4096) / 1024))

printf '['
first=1
for pid_dir in /proc/[0-9]*; do
  pid="$(basename "$pid_dir")"
  [ -r "$pid_dir/stat" ] || continue
  [ -r "$pid_dir/status" ] || continue

  stat_line="$(cat "$pid_dir/stat" 2>/dev/null)" || continue
  comm="$(awk '/^Name:/ {print $2}' "$pid_dir/status" 2>/dev/null)"
  state="$(awk '/^State:/ {print $2}' "$pid_dir/status" 2>/dev/null)"
  vm_rss_kb="$(awk '/^VmRSS:/ {print $2}' "$pid_dir/status" 2>/dev/null)"
  [ -z "$vm_rss_kb" ] && vm_rss_kb=0
  ppid="$(awk '/^PPid:/ {print $2}' "$pid_dir/status" 2>/dev/null)"
  uid="$(awk '/^Uid:/ {print $2}' "$pid_dir/status" 2>/dev/null)"
  threads="$(awk '/^Threads:/ {print $2}' "$pid_dir/status" 2>/dev/null)"

  # CPU % estimation from /proc/[pid]/stat fields 14+15
  utime=$(echo "$stat_line" | awk '{print $14}')
  stime=$(echo "$stat_line" | awk '{print $15}')
  starttime=$(echo "$stat_line" | awk '{print $22}')
  total_time=$((utime + stime))
  elapsed=$((uptime_ticks - starttime))
  if [ "$elapsed" -gt 0 ] 2>/dev/null; then
    cpu_pct=$((total_time * 100 / elapsed))
  else
    cpu_pct=0
  fi

  # Memory %
  if [ "$mem_total_kb" -gt 0 ] 2>/dev/null; then
    mem_pct=$((vm_rss_kb * 100 / mem_total_kb))
  else
    mem_pct=0
  fi

  # Format RSS
  if [ "$vm_rss_kb" -ge 1048576 ]; then
    rss_fmt="$((vm_rss_kb / 1048576))G"
  elif [ "$vm_rss_kb" -ge 1024 ]; then
    rss_fmt="$((vm_rss_kb / 1024))M"
  else
    rss_fmt="${vm_rss_kb}K"
  fi

  # cmdline
  cmdline="$(tr '\0' ' ' < "$pid_dir/cmdline" 2>/dev/null | head -c 120)"
  [ -z "$cmdline" ] && cmdline="[$comm]"
  # Escape quotes for JSON
  cmdline="$(echo "$cmdline" | sed 's/"/\\"/g')"

  [ "$first" = 1 ] && first=0 || printf ','
  printf '{"pid":%s,"name":"%s","state":"%s","ppid":%s,"uid":%s,"threads":%s,"cpu_pct":%s,"mem_pct":%s,"rss":"%s","rss_kb":%s,"cmdline":"%s"}' \
    "$pid" "$comm" "$state" "${ppid:-0}" "${uid:-0}" "${threads:-1}" "$cpu_pct" "$mem_pct" "$rss_fmt" "$vm_rss_kb" "$cmdline"
done
printf ']'
