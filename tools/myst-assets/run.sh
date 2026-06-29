#!/usr/bin/env bash
# Avvio in foreground (sviluppo). Per demone: ./daemon.sh start
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
source "$ROOT/_common.sh"

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8765}"
# --reload può dare problemi in accesso LAN; usa RELOAD=1 solo in sviluppo locale.
RELOAD="${RELOAD:-0}"

myst_assets_ensure_venv "$ROOT"

LIB_DIR="$(myst_assets_resolve_lib_dir "$ROOT")"
export MYST_LIB_DIR="$LIB_DIR"
echo "Myst asset source: $LIB_DIR"

myst_assets_ensure_db "$ROOT" "$LIB_DIR"

myst_assets_print_urls "$HOST" "$PORT"
echo "(Ctrl+C per fermare — in produzione usa: ./daemon.sh start)"

cd "$ROOT"
UVICORN_ARGS=(server:app --host "$HOST" --port "$PORT")
if [[ "$RELOAD" == "1" ]]; then
  UVICORN_ARGS+=(--reload)
fi

exec .venv/bin/python -m uvicorn "${UVICORN_ARGS[@]}"
