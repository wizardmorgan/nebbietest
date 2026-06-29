#!/usr/bin/env bash
# Gestione demone Myst Asset Browser: start | stop | restart | status | logs
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
source "$ROOT/_common.sh"

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8765}"
PIDFILE="$ROOT/myst-assets.pid"
LOGDIR="$ROOT/logs"
LOGFILE="$LOGDIR/server.log"

daemon_is_running() {
  [[ -f "$PIDFILE" ]] || return 1
  local pid
  pid="$(cat "$PIDFILE")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

daemon_start() {
  if daemon_is_running; then
    echo "Già in esecuzione (PID $(cat "$PIDFILE"))."
    daemon_status
    return 0
  fi

  myst_assets_ensure_venv "$ROOT"

  LIB_DIR="$(myst_assets_resolve_lib_dir "$ROOT")"
  export MYST_LIB_DIR="$LIB_DIR"
  myst_assets_ensure_db "$ROOT" "$LIB_DIR"

  mkdir -p "$LOGDIR"
  cd "$ROOT"

  echo "Avvio demone Myst Asset Browser..."
  echo "Asset source: $LIB_DIR"
  myst_assets_print_urls "$HOST" "$PORT"

  nohup .venv/bin/python -m uvicorn server:app \
    --host "$HOST" \
    --port "$PORT" \
    --access-log \
    --log-level info \
    >>"$LOGFILE" 2>&1 &

  echo $! >"$PIDFILE"
  sleep 0.5

  if daemon_is_running; then
    echo "Avviato (PID $(cat "$PIDFILE")). Log: $LOGFILE"
  else
    echo "Errore avvio. Ultime righe del log:" >&2
    tail -20 "$LOGFILE" >&2 || true
    rm -f "$PIDFILE"
    return 1
  fi
}

daemon_stop() {
  if ! daemon_is_running; then
    echo "Non in esecuzione."
    rm -f "$PIDFILE"
    return 0
  fi
  local pid
  pid="$(cat "$PIDFILE")"
  echo "Arresto PID $pid..."
  kill "$pid" 2>/dev/null || true
  for _ in $(seq 1 20); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "Invio SIGKILL..."
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$PIDFILE"
  echo "Fermato."
}

daemon_status() {
  if daemon_is_running; then
    echo "In esecuzione — PID $(cat "$PIDFILE"), porta $PORT"
    myst_assets_print_urls "$HOST" "$PORT"
    if command -v ss >/dev/null 2>&1; then
      ss -tlnp 2>/dev/null | grep ":$PORT " || true
    fi
  else
    echo "Non in esecuzione."
    [[ -f "$PIDFILE" ]] && rm -f "$PIDFILE"
    return 1
  fi
}

daemon_logs() {
  mkdir -p "$LOGDIR"
  touch "$LOGFILE"
  tail -f "$LOGFILE"
}

usage() {
  cat <<EOF
Uso: $0 {start|stop|restart|status|logs}

Variabili d'ambiente:
  HOST=0.0.0.0   interfaccia di ascolto (default: tutte)
  PORT=8765        porta TCP
  MYST_LIB_DIR=    directory con myst.zon (auto-detect se omessa)

Esempi:
  ./daemon.sh start
  PORT=9000 ./daemon.sh restart
  ./daemon.sh logs
EOF
}

cmd="${1:-}"
case "$cmd" in
  start) daemon_start ;;
  stop) daemon_stop ;;
  restart) daemon_stop; daemon_start ;;
  status) daemon_status ;;
  logs) daemon_logs ;;
  *)
    usage
    exit 1
    ;;
esac
