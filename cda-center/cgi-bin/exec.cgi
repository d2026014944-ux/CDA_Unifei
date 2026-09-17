#!/bin/sh
# CGI: Execute shell command — real terminal backend
# Security: only accessible from localhost via busybox httpd inside VM
printf 'Content-Type: application/json\r\n\r\n'

# Read POST body (command to execute) or GET from query string
cmd=""
if [ "$REQUEST_METHOD" = "POST" ]; then
  read -r body
  # URL-decode the cmd parameter: cmd=ls+-la
  cmd="$(echo "$body" | sed 's/^cmd=//; s/+/ /g; s/%2F/\//g; s/%20/ /g; s/%3A/:/g; s/%2D/-/g; s/%5F/_/g; s/%2E/./g; s/%7C/|/g; s/%26/\&/g; s/%3B/;/g; s/%3D/=/g')"
elif [ -n "$QUERY_STRING" ]; then
  cmd="$(echo "$QUERY_STRING" | sed 's/^cmd=//; s/+/ /g; s/%2F/\//g; s/%20/ /g; s/%3A/:/g; s/%2D/-/g; s/%5F/_/g; s/%2E/./g; s/%7C/|/g; s/%26/\&/g; s/%3B/;/g; s/%3D/=/g')"
fi

if [ -z "$cmd" ]; then
  printf '{"rc":-1,"stdout":"","stderr":"error: no command provided"}'
  exit 0
fi

# Blocklist: prevent destructive commands inside the dashboard
case "$cmd" in
  *rm\ -rf*|*mkfs*|*dd\ if=*|*shutdown*|*reboot*|*halt*|*poweroff*|*init\ 0*|*init\ 6*)
    printf '{"rc":126,"stdout":"","stderr":"blocked: destructive command not allowed from dashboard"}'
    exit 0
    ;;
esac

# Execute with timeout (busybox timeout or fallback)
output_file="/tmp/cda_exec_out.$$"
error_file="/tmp/cda_exec_err.$$"

if command -v timeout >/dev/null 2>&1; then
  timeout 10 sh -c "$cmd" >"$output_file" 2>"$error_file"
else
  sh -c "$cmd" >"$output_file" 2>"$error_file"
fi
rc=$?

stdout="$(cat "$output_file" 2>/dev/null | head -c 8192 | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' '\n')"
stderr="$(cat "$error_file" 2>/dev/null | head -c 2048 | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' '\n')"
rm -f "$output_file" "$error_file"

# We need to properly escape newlines for JSON
stdout_json="$(cat "$output_file" 2>/dev/null | head -c 8192 | awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t"); printf "%s\\n", $0}')"
stderr_json="$(cat "$error_file" 2>/dev/null | head -c 2048 | awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t"); printf "%s\\n", $0}')"

# Re-read since the files were already deleted — recreate approach
output_file2="/tmp/cda_exec_out2.$$"
error_file2="/tmp/cda_exec_err2.$$"
if command -v timeout >/dev/null 2>&1; then
  timeout 10 sh -c "$cmd" >"$output_file2" 2>"$error_file2"
else
  sh -c "$cmd" >"$output_file2" 2>"$error_file2"
fi
rc=$?

# Build JSON-safe output
printf '{"rc":%d,"stdout":"' "$rc"
awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t"); printf "%s\\n", $0}' "$output_file2" 2>/dev/null
printf '","stderr":"'
awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t"); printf "%s\\n", $0}' "$error_file2" 2>/dev/null
printf '"}'

rm -f "$output_file2" "$error_file2"
