#!/bin/sh
# CGI: System logs — reads from dmesg and /var/log
printf 'Content-Type: application/json\r\n\r\n'

# Query string parsing: ?source=dmesg&lines=50
source="dmesg"
max_lines=80
if [ -n "$QUERY_STRING" ]; then
  for param in $(echo "$QUERY_STRING" | tr '&' ' '); do
    key="${param%%=*}"
    val="${param#*=}"
    case "$key" in
      source) source="$val" ;;
      lines)  max_lines="$val" ;;
    esac
  done
fi

printf '{"source":"%s","entries":[' "$source"

first=1
case "$source" in
  dmesg)
    dmesg 2>/dev/null | tail -n "$max_lines" | while IFS= read -r line; do
      # Extract timestamp if present [12345.678901]
      ts=""
      msg="$line"
      case "$line" in
        \[*\]*)
          ts="$(echo "$line" | sed 's/^\[\s*\([0-9.]*\)\].*/\1/')"
          msg="$(echo "$line" | sed 's/^\[[^]]*\]\s*//')"
          ;;
      esac
      # Determine level
      level="info"
      case "$msg" in
        *error*|*Error*|*ERROR*|*fail*|*Fail*|*FAIL*) level="err" ;;
        *warn*|*Warn*|*WARN*) level="warn" ;;
        *audit*|*AUDIT*) level="audit" ;;
      esac
      # Escape
      msg_esc="$(echo "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | head -c 300)"
      [ "$first" = 1 ] && first=0 || printf ','
      printf '{"ts":"%s","level":"%s","msg":"%s"}' "$ts" "$level" "$msg_esc"
    done
    ;;
  syslog)
    if [ -r /var/log/syslog ]; then
      tail -n "$max_lines" /var/log/syslog
    elif [ -r /var/log/messages ]; then
      tail -n "$max_lines" /var/log/messages
    else
      echo "no syslog available"
    fi 2>/dev/null | while IFS= read -r line; do
      msg_esc="$(echo "$line" | sed 's/\\/\\\\/g; s/"/\\"/g' | head -c 300)"
      [ "$first" = 1 ] && first=0 || printf ','
      printf '{"ts":"","level":"info","msg":"%s"}' "$msg_esc"
    done
    ;;
  journal)
    if command -v journalctl >/dev/null 2>&1; then
      journalctl --no-pager -n "$max_lines" -o short-precise 2>/dev/null | while IFS= read -r line; do
        msg_esc="$(echo "$line" | sed 's/\\/\\\\/g; s/"/\\"/g' | head -c 300)"
        [ "$first" = 1 ] && first=0 || printf ','
        printf '{"ts":"","level":"info","msg":"%s"}' "$msg_esc"
      done
    fi
    ;;
  boot)
    # CDA-specific boot log from /run/cda
    for meta in boot-mode deployment-name deployment-version deployment-slot deployment-source boot-source; do
      val=""
      [ -r "/run/cda/$meta" ] && val="$(cat "/run/cda/$meta" 2>/dev/null)"
      [ "$first" = 1 ] && first=0 || printf ','
      printf '{"ts":"boot","level":"info","msg":"[%s] %s"}' "$meta" "$val"
    done
    ;;
esac

printf ']}'
