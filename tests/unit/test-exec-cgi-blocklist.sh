#!/bin/sh
# test-exec-cgi-blocklist.sh — Testa se exec.cgi bloqueia comandos destrutivos
# Simula chamadas ao CGI verificando que a blocklist impede execução perigosa.
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CGI="$ROOT_DIR/cda-center/cgi-bin/exec.cgi"
FAILED=0

assert_blocked() {
  cmd="$1"
  label="$2"

  # Simula ambiente CGI com o comando via QUERY_STRING
  encoded_cmd="$(printf '%s' "$cmd" | sed 's/ /+/g; s|/|%2F|g')"
  export REQUEST_METHOD="GET"
  export QUERY_STRING="cmd=$encoded_cmd"

  output="$(sh "$CGI" 2>/dev/null)" || true

  case "$output" in
    *'"rc":126'*|*'blocked'*)
      printf '[PASS] bloqueado: %s\n' "$label"
      ;;
    *)
      printf '[FAIL] NÃO bloqueado: %s => %s\n' "$label" "$output" >&2
      FAILED=1
      ;;
  esac

  unset REQUEST_METHOD QUERY_STRING
}

assert_allowed() {
  cmd="$1"
  label="$2"

  encoded_cmd="$(printf '%s' "$cmd" | sed 's/ /+/g; s|/|%2F|g')"
  export REQUEST_METHOD="GET"
  export QUERY_STRING="cmd=$encoded_cmd"

  output="$(sh "$CGI" 2>/dev/null)" || true

  case "$output" in
    *'"rc":126'*|*'blocked'*)
      printf '[FAIL] bloqueado indevidamente: %s\n' "$label" >&2
      FAILED=1
      ;;
    *)
      printf '[PASS] permitido: %s\n' "$label"
      ;;
  esac

  unset REQUEST_METHOD QUERY_STRING
}

echo "=== Teste: Blocklist do Terminal Web (exec.cgi) ==="

# Comandos que DEVEM ser bloqueados
assert_blocked "rm -rf /"                  "rm -rf /"
assert_blocked "rm -rf /home"              "rm -rf /home"
assert_blocked "mkfs /dev/sda"             "mkfs /dev/sda"
assert_blocked "mkfs.ext4 /dev/sda1"       "mkfs.ext4 (contém mkfs)"
assert_blocked "dd if=/dev/zero of=/dev/sda" "dd if= (disk destroyer)"
assert_blocked "shutdown -h now"           "shutdown"
assert_blocked "reboot"                    "reboot"
assert_blocked "halt"                      "halt"
assert_blocked "poweroff"                  "poweroff"
assert_blocked "init 0"                    "init 0 (halt)"
assert_blocked "init 6"                    "init 6 (reboot)"

# Comandos que DEVEM ser permitidos
assert_allowed "echo hello"                "echo hello"
assert_allowed "uname -a"                  "uname -a"
assert_allowed "cat /proc/meminfo"         "cat /proc/meminfo"
assert_allowed "ls /tmp"                   "ls /tmp"
assert_allowed "hostname"                  "hostname"

# Teste de comando vazio
export REQUEST_METHOD="GET"
export QUERY_STRING=""
empty_out="$(sh "$CGI" 2>/dev/null)" || true
case "$empty_out" in
  *'"rc":-1'*|*'no command'*)
    printf '[PASS] comando vazio tratado\n'
    ;;
  *)
    printf '[FAIL] comando vazio não tratado: %s\n' "$empty_out" >&2
    FAILED=1
    ;;
esac
unset REQUEST_METHOD QUERY_STRING

if [ "$FAILED" -ne 0 ]; then
  echo "[RESULTADO] FALHAS ENCONTRADAS" >&2
  exit 1
fi

echo "[ok] exec.cgi blocklist — todos os testes passaram"
