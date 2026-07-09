#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
  .venv/bin/pip install -r requirements.txt
fi

if [[ ! -f myst_assets.db ]]; then
  .venv/bin/python import_db.py
fi

exec .venv/bin/uvicorn server:app --host 0.0.0.0 --port "${PORT:-8765}" --reload
