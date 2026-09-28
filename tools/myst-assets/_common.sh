#!/usr/bin/env bash
# Shared setup for run.sh and daemon.sh (source, do not execute directly).

myst_assets_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

myst_assets_ensure_venv() {
  local root="$1"
  local python="${PYTHON:-python3}"
  cd "$root"

  if [[ ! -x .venv/bin/python ]]; then
    echo "Creating virtualenv in $root/.venv"
    "$python" -m venv .venv
  fi

  echo "Installing dependencies..."
  .venv/bin/pip install -q -r requirements.txt

  if ! .venv/bin/python -m uvicorn --version >/dev/null 2>&1; then
    echo "Errore: uvicorn non installato. Prova: rm -rf .venv && ./run.sh" >&2
    return 1
  fi
}

myst_assets_resolve_lib_dir() {
  local root="$1"
  cd "$root"
  .venv/bin/python -c "from myst_paths import resolve_lib_dir; print(resolve_lib_dir())"
}

myst_assets_ensure_db() {
  local root="$1"
  local lib_dir="$2"
  cd "$root"
  if [[ ! -f myst_assets.db ]]; then
    .venv/bin/python import_db.py --lib-dir "$lib_dir"
  fi
}

myst_assets_primary_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

myst_assets_print_urls() {
  local host="$1"
  local port="$2"
  local ip
  ip="$(myst_assets_primary_ip)"
  echo "In ascolto su http://${host}:${port}/"
  if [[ -n "$ip" && "$host" == "0.0.0.0" ]]; then
    echo "Accesso LAN: http://${ip}:${port}/"
  fi
}
