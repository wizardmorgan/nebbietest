#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
  .venv/bin/pip install -r requirements.txt
fi

# Risolve la directory asset (root repo su mudlet, mudroot/lib in sviluppo, o MYST_LIB_DIR).
LIB_DIR="$(
  .venv/bin/python -c "from myst_paths import resolve_lib_dir; print(resolve_lib_dir())"
)"
export MYST_LIB_DIR="$LIB_DIR"
echo "Myst asset source: $LIB_DIR"

if [[ ! -f myst_assets.db ]]; then
  .venv/bin/python import_db.py --lib-dir "$LIB_DIR"
fi

exec .venv/bin/uvicorn server:app --host 0.0.0.0 --port "${PORT:-8765}" --reload
