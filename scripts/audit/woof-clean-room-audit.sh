#!/bin/sh
set -eu

TARGET_DIR="${1:-/home/runner/work/CDA_Unifei/CDA_Unifei}"
WOOF_DIR="${2:-}"

if [ -z "$WOOF_DIR" ] || [ ! -d "$WOOF_DIR" ]; then
  echo "uso: $0 <target-dir> <woof-ce-dir>" >&2
  exit 2
fi

TMP_DIR="$(mktemp -d /tmp/cda-cleanroom.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

SCRIPT_LIST="$TMP_DIR/scripts.list"
find "$TARGET_DIR" -type f \( -name '*.sh' -o -name '*.service' -o -name '*.conf' -o -name '*.xml' \) > "$SCRIPT_LIST"

VAR_TOKENS="$TMP_DIR/vars.tokens"
FLOW_LINES="$TMP_DIR/flows.tokens"
MATCH_REPORT="$TMP_DIR/matches.report"

awk '
  {
    while (match($0, /[A-Za-z_][A-Za-z0-9_]{5,}/)) {
      tok=substr($0, RSTART, RLENGTH)
      if (tok !~ /^(printf|echo|mount|mkdir|while|until|return|switch_root|systemd|overlay|tmpfs|squashfs)$/) {
        print tok
      }
      $0=substr($0, RSTART+RLENGTH)
    }
  }
' $(cat "$SCRIPT_LIST") | sort -u > "$VAR_TOKENS"

grep -hE '^[[:space:]]*(if|elif|case|while|for)[[:space:]]' $(cat "$SCRIPT_LIST") | sed 's/[[:space:]]\+/ /g' | sort -u > "$FLOW_LINES"

: > "$MATCH_REPORT"

while IFS= read -r token; do
  [ "${#token}" -ge 8 ] || continue
  grep -Rnw -- "$token" "$WOOF_DIR" >> "$MATCH_REPORT" || true
done < "$VAR_TOKENS"

while IFS= read -r flow; do
  [ -n "$flow" ] || continue
  grep -RFn -- "$flow" "$WOOF_DIR" >> "$MATCH_REPORT" || true
done < "$FLOW_LINES"

if [ -s "$MATCH_REPORT" ]; then
  echo "[reprovado] auditoria detectou similaridade potencial com Woof-CE" >&2
  cat "$MATCH_REPORT" >&2
  exit 1
fi

echo "[aprovado] auditoria clean room sem similaridade relevante"
