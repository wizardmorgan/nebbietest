#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

PYTHON="${PYTHON:-python3}"

if [[ ! -x .venv/bin/python ]]; then
  echo "Creating virtualenv in $ROOT/.venv"
  "$PYTHON" -m venv .venv
fi

echo "Installing dependencies..."
.venv/bin/pip install -q -r requirements.txt

if ! .venv/bin/python -m uvicorn --version >/dev/null 2>&1; then
  echo "Errore: uvicorn non installato. Prova:" >&2
  echo "  rm -rf .venv && ./run.sh" >&2
  exit 1
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

exec .venv/bin/python -m uvicorn server:app --host 0.0.0.0 --port "${PORT:-8765}" --reload
