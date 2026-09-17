#!/bin/sh
# CGI: Service actions — start/stop/restart/status via systemctl or direct
printf 'Content-Type: application/json\r\n\r\n'

# Parse query string: ?action=status&service=cda-batman-adv
action=""
service=""
if [ -n "$QUERY_STRING" ]; then
  for param in $(echo "$QUERY_STRING" | tr '&' ' '); do
    key="${param%%=*}"
    val="${param#*=}"
    case "$key" in
      action)  action="$val" ;;
      service) service="$val" ;;
    esac
  done
fi

# Whitelist of allowed services
allowed="cda-batman-adv avahi-daemon"
service_ok=0
for s in $allowed; do
  [ "$s" = "$service" ] && service_ok=1
done

if [ "$service_ok" != 1 ] && [ "$action" != "list" ]; then
  printf '{"error":"service not allowed: %s","allowed":["%s"]}' "$service" "$(echo "$allowed" | sed 's/ /","/g')"
  exit 0
fi

case "$action" in
  status)
    if command -v systemctl >/dev/null 2>&1; then
      state="$(systemctl is-active "$service" 2>/dev/null || echo unknown)"
      enabled="$(systemctl is-enabled "$service" 2>/dev/null || echo unknown)"
      printf '{"service":"%s","state":"%s","enabled":"%s"}' "$service" "$state" "$enabled"
    else
      # Fallback: check if process is running
      pid="$(pidof "$service" 2>/dev/null || echo "")"
      if [ -n "$pid" ]; then
        printf '{"service":"%s","state":"active","enabled":"unknown","pid":"%s"}' "$service" "$pid"
      else
        printf '{"service":"%s","state":"inactive","enabled":"unknown"}' "$service"
      fi
    fi
    ;;
  start|stop|restart)
    if command -v systemctl >/dev/null 2>&1; then
      systemctl "$action" "$service" 2>/dev/null
      rc=$?
      state="$(systemctl is-active "$service" 2>/dev/null || echo unknown)"
      printf '{"service":"%s","action":"%s","rc":%d,"state":"%s"}' "$service" "$action" "$rc" "$state"
    else
      printf '{"error":"systemctl not available"}'
    fi
    ;;
  list)
    printf '{"services":['
    first=1
    if command -v systemctl >/dev/null 2>&1; then
      systemctl list-units --type=service --no-pager --no-legend 2>/dev/null | while IFS= read -r line; do
        unit="$(echo "$line" | awk '{print $1}')"
        load="$(echo "$line" | awk '{print $2}')"
        active="$(echo "$line" | awk '{print $3}')"
        sub="$(echo "$line" | awk '{print $4}')"
        desc="$(echo "$line" | awk '{$1=$2=$3=$4=""; gsub(/^[ \t]+/,"",$0); print}' | sed 's/"/\\"/g' | head -c 120)"
        [ "$first" = 1 ] && first=0 || printf ','
        printf '{"unit":"%s","load":"%s","active":"%s","sub":"%s","desc":"%s"}' "$unit" "$load" "$active" "$sub" "$desc"
      done
    else
      # Fallback: list known CDA services
      for svc in cda-batman-adv avahi-daemon httpd; do
        pid="$(pidof "$svc" 2>/dev/null || echo "")"
        state="inactive"
        [ -n "$pid" ] && state="active"
        [ "$first" = 1 ] && first=0 || printf ','
        printf '{"unit":"%s","load":"loaded","active":"%s","sub":"running","desc":"CDA service"}' "$svc" "$state"
      done
    fi
    printf ']}'
    ;;
  *)
    printf '{"error":"unknown action: %s, valid: status|start|stop|restart|list"}' "$action"
    ;;
esac
