#!/bin/sh
# test-cgi-json-validity.sh — Verifica que todos os CGI scripts retornam JSON válido
# Simula chamadas GET/POST e valida a estrutura do output.
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CGI_DIR="$ROOT_DIR/cda-center/cgi-bin"
FAILED=0

# Verificação JSON básica sem dependência de jq:
# - Começa com { ou [
# - Termina com } ou ]
# - Contém pelo menos uma chave entre aspas
validate_json_structure() {
  output="$(printf '%s' "$1" | tr -d '\r')"
  label="$2"

  # Remove o cabeçalho HTTP (Content-Type: ...) se presente
  body="$(echo "$output" | sed '1,/^[[:space:]]*$/d')"

  # Se body vazio, tenta usar output inteiro (CGI pode não ter headers separados)
  if [ -z "$body" ]; then
    body="$output"
  fi

  # Remove espaços iniciais/finais
  body="$(echo "$body" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  if [ -z "$body" ]; then
    printf '[FAIL] %s: output vazio\n' "$label" >&2
    return 1
  fi

  # Verifica se começa com { ou [
  first_char="$(printf '%s' "$body" | head -n 1 | cut -c1)"
  case "$first_char" in
    '{'|'[') ;;
    *)
      printf '[FAIL] %s: não começa com { ou [ (começa com: %s)\n' "$label" "$first_char" >&2
      printf '  Output: %.200s\n' "$body" >&2
      return 1
      ;;
  esac

  # Verifica se contém pelo menos uma chave JSON ("key":)
  if ! echo "$body" | grep -q '"[^"]*"[[:space:]]*:'; then
    # Pode ser um array vazio [] ou array de primitivos — aceitável
    case "$body" in
      '['*']') ;;
      *)
        printf '[FAIL] %s: nenhuma chave JSON detectada\n' "$label" >&2
        printf '  Output: %.200s\n' "$body" >&2
        return 1
        ;;
    esac
  fi

  # Verifica balanceamento básico de chaves/colchetes
  open_braces="$(printf '%s' "$body" | tr -cd '{' | wc -c)"
  close_braces="$(printf '%s' "$body" | tr -cd '}' | wc -c)"
  open_brackets="$(printf '%s' "$body" | tr -cd '[' | wc -c)"
  close_brackets="$(printf '%s' "$body" | tr -cd ']' | wc -c)"

  if [ "$open_braces" != "$close_braces" ]; then
    printf '[FAIL] %s: chaves desbalanceadas ({ = %s, } = %s)\n' "$label" "$open_braces" "$close_braces" >&2
    return 1
  fi

  if [ "$open_brackets" != "$close_brackets" ]; then
    printf '[FAIL] %s: colchetes desbalanceados ([ = %s, ] = %s)\n' "$label" "$open_brackets" "$close_brackets" >&2
    return 1
  fi

  printf '[PASS] %s: JSON estruturalmente válido\n' "$label"
  return 0
}

echo "=== Teste: Validação de JSON nos CGI Scripts ==="

# sysinfo.cgi — Sem parâmetros
export REQUEST_METHOD="GET"
export QUERY_STRING=""
out="$(sh "$CGI_DIR/sysinfo.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "sysinfo.cgi" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

# processes.cgi — Sem parâmetros
export REQUEST_METHOD="GET"
export QUERY_STRING=""
out="$(sh "$CGI_DIR/processes.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "processes.cgi" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

# network.cgi — Sem parâmetros
export REQUEST_METHOD="GET"
export QUERY_STRING=""
out="$(sh "$CGI_DIR/network.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "network.cgi" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

# storage.cgi — Sem parâmetros
export REQUEST_METHOD="GET"
export QUERY_STRING=""
out="$(sh "$CGI_DIR/storage.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "storage.cgi" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

# logs.cgi — Fonte padrão (dmesg)
export REQUEST_METHOD="GET"
export QUERY_STRING="source=dmesg&lines=5"
out="$(sh "$CGI_DIR/logs.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "logs.cgi (dmesg)" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

# services.cgi — Ação list
export REQUEST_METHOD="GET"
export QUERY_STRING="action=list"
out="$(sh "$CGI_DIR/services.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "services.cgi (list)" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

# services.cgi — Serviço não permitido
export REQUEST_METHOD="GET"
export QUERY_STRING="action=status&service=sshd"
out="$(sh "$CGI_DIR/services.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "services.cgi (not allowed)" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

# exec.cgi — Comando válido
export REQUEST_METHOD="GET"
export QUERY_STRING="cmd=echo+hello"
out="$(sh "$CGI_DIR/exec.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "exec.cgi (echo hello)" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

# exec.cgi — Comando bloqueado
export REQUEST_METHOD="GET"
export QUERY_STRING="cmd=rm+-rf+%2F"
out="$(sh "$CGI_DIR/exec.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "exec.cgi (blocked cmd)" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

# exec.cgi — Comando vazio
export REQUEST_METHOD="GET"
export QUERY_STRING=""
out="$(sh "$CGI_DIR/exec.cgi" 2>/dev/null)" || true
validate_json_structure "$out" "exec.cgi (empty)" || FAILED=1
unset REQUEST_METHOD QUERY_STRING

if [ "$FAILED" -ne 0 ]; then
  echo "[RESULTADO] FALHAS ENCONTRADAS — Alguns CGIs retornam JSON inválido" >&2
  exit 1
fi

echo "[ok] cgi-json-validity — todos os CGI scripts retornam JSON estruturalmente válido"
