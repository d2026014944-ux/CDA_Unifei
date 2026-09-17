#!/bin/sh
# CGI: System information — reads from /proc, uname, /run/cda
printf 'Content-Type: application/json\r\n\r\n'

hostname="$(hostname 2>/dev/null || echo unknown)"
kernel="$(uname -r 2>/dev/null || echo unknown)"
arch="$(uname -m 2>/dev/null || echo unknown)"
uptime_raw="$(cat /proc/uptime 2>/dev/null | awk '{print $1}')"
uptime_sec="${uptime_raw%%.*}"
if [ -n "$uptime_sec" ]; then
  up_d=$((uptime_sec / 86400))
  up_h=$(((uptime_sec % 86400) / 3600))
  up_m=$(((uptime_sec % 3600) / 60))
  uptime_fmt="${up_d}d ${up_h}h ${up_m}m"
else
  uptime_fmt="unknown"
fi

# Load average
loadavg="$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')"
load1="$(echo "$loadavg" | awk '{print $1}')"
load5="$(echo "$loadavg" | awk '{print $2}')"
load15="$(echo "$loadavg" | awk '{print $3}')"

# Memory from /proc/meminfo (in kB)
mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
mem_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null)
mem_free=$(awk '/^MemFree:/ {print $2}' /proc/meminfo 2>/dev/null)
buffers=$(awk '/^Buffers:/ {print $2}' /proc/meminfo 2>/dev/null)
cached=$(awk '/^Cached:/ {print $2}' /proc/meminfo 2>/dev/null)
swap_total=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
swap_free=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo 2>/dev/null)

mem_used=$((mem_total - mem_available))
mem_total_mib=$((mem_total / 1024))
mem_used_mib=$((mem_used / 1024))
mem_available_mib=$((mem_available / 1024))
buffers_mib=$((buffers / 1024))
cached_mib=$((cached / 1024))

if [ "$mem_total" -gt 0 ] 2>/dev/null; then
  mem_pct=$((mem_used * 100 / mem_total))
else
  mem_pct=0
fi

# CPU info
cpu_model="$(awk -F: '/^model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
cpu_cores="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)"

# CPU usage from /proc/stat (instantaneous snapshot)
cpu_line="$(head -1 /proc/stat 2>/dev/null)"
cpu_user=$(echo "$cpu_line" | awk '{print $2}')
cpu_nice=$(echo "$cpu_line" | awk '{print $3}')
cpu_system=$(echo "$cpu_line" | awk '{print $4}')
cpu_idle=$(echo "$cpu_line" | awk '{print $5}')
cpu_total=$((cpu_user + cpu_nice + cpu_system + cpu_idle))
if [ "$cpu_total" -gt 0 ] 2>/dev/null; then
  cpu_busy=$((cpu_user + cpu_nice + cpu_system))
  cpu_pct=$((cpu_busy * 100 / cpu_total))
else
  cpu_pct=0
fi

# Boot info from /run/cda/
boot_mode="$(cat /run/cda/boot-mode 2>/dev/null || echo unknown)"
deploy_name="$(cat /run/cda/deployment-name 2>/dev/null || echo unknown)"
deploy_version="$(cat /run/cda/deployment-version 2>/dev/null || echo unknown)"
deploy_slot="$(cat /run/cda/deployment-slot 2>/dev/null || echo unknown)"

# Process count
proc_count="$(ls -1d /proc/[0-9]* 2>/dev/null | wc -l)"

cat <<JSON
{
  "hostname": "$hostname",
  "kernel": "$kernel",
  "arch": "$arch",
  "uptime": "$uptime_fmt",
  "uptime_sec": $uptime_sec,
  "load": { "1m": $load1, "5m": $load5, "15m": $load15 },
  "memory": {
    "total_mib": $mem_total_mib,
    "used_mib": $mem_used_mib,
    "available_mib": $mem_available_mib,
    "buffers_mib": $buffers_mib,
    "cached_mib": $cached_mib,
    "pct": $mem_pct
  },
  "swap": {
    "total_kb": ${swap_total:-0},
    "free_kb": ${swap_free:-0}
  },
  "cpu": {
    "model": "$cpu_model",
    "cores": $cpu_cores,
    "pct": $cpu_pct
  },
  "boot": {
    "mode": "$boot_mode",
    "deployment_name": "$deploy_name",
    "deployment_version": "$deploy_version",
    "deployment_slot": "$deploy_slot"
  },
  "processes": $proc_count
}
JSON
