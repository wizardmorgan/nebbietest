#!/usr/bin/env bash
# Bootstrap idempotente per Cursor Cloud Agents (vedi .cursor/environment.json).
# Installa dipendenze di sistema mancanti + bootstrap repo (getworldlocal).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

install_apt() {
  local pkg="$1"
  if command -v "$pkg" >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "cursor-cloud-agent-install: apt-get non disponibile, salto $pkg" >&2
    return 1
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg"
  else
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg"
  fi
}

# Fallback se il Dockerfile non è stato ancora ricostruito
install_apt sshpass || true
install_apt git || true
install_apt openssh-client || true

if [[ -x "$ROOT/getworldlocal" ]]; then
  "$ROOT/getworldlocal"
fi

if command -v sshpass >/dev/null 2>&1; then
  echo "cursor-cloud-agent-install: sshpass ok ($(sshpass -V 2>&1 | head -1))"
else
  echo "cursor-cloud-agent-install: AVVISO sshpass non installato" >&2
fi
