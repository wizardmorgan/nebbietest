#!/usr/bin/env bash
# Diagnostica accesso LAN al Myst Asset Browser
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
source "$ROOT/_common.sh"

PORT="${PORT:-8765}"
LAN_IP="$(myst_assets_primary_ip || true)"
PIDFILE="$ROOT/myst-assets.pid"

daemon_is_running() {
  [[ -f "$PIDFILE" ]] || return 1
  kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

echo "=== Myst Asset Browser — check LAN ==="
echo "Porta: $PORT"
echo "IP LAN rilevato: ${LAN_IP:-n/d}"
echo

if command -v ss >/dev/null 2>&1; then
  echo "--- Socket in ascolto ---"
  ss -tlnp 2>/dev/null | grep ":$PORT " || echo "(nessun processo in ascolto su $PORT)"
  echo
fi

if ! daemon_is_running; then
  if [[ -f "$PIDFILE" ]]; then
    echo "ATTENZIONE: PID file presente ma processo non attivo."
  else
    echo "Server non in esecuzione. Avvia con: ./daemon.sh start"
  fi
  echo
fi

check_url() {
  local label="$1"
  local url="$2"
  printf "%-28s " "$label"
  if curl -fsS --max-time 5 "$url" >/dev/null; then
    echo "OK  $url"
    return 0
  fi
  echo "FAIL $url"
  return 1
}

FAIL=0
check_url "localhost health" "http://127.0.0.1:$PORT/health" || FAIL=1
check_url "localhost home" "http://127.0.0.1:$PORT/" || FAIL=1
check_url "localhost static JS" "http://127.0.0.1:$PORT/static/app.js" || FAIL=1
check_url "localhost API meta" "http://127.0.0.1:$PORT/api/meta" || FAIL=1

if [[ -n "$LAN_IP" ]]; then
  check_url "LAN health" "http://$LAN_IP:$PORT/health" || FAIL=1
  check_url "LAN home" "http://$LAN_IP:$PORT/" || FAIL=1
  check_url "LAN static JS" "http://$LAN_IP:$PORT/static/app.js" || FAIL=1
fi

echo
echo "--- Test HTTPS (deve fallire: nessun TLS) ---"
if curl -kfsS --max-time 3 "https://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  echo "HTTPS risponde (inaspettato)"
else
  echo "HTTPS non disponibile (corretto). Usa http:// nel browser."
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "Tutti i test HTTP OK."
  if [[ -n "$LAN_IP" ]]; then
    echo "Apri nel browser: http://$LAN_IP:$PORT/"
    echo "IMPORTANTE: http:// esplicito — non https://"
  fi
else
  echo "Alcuni test falliti. Log: $ROOT/logs/server.log"
  exit 1
fi
