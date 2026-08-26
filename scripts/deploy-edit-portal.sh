#!/bin/bash
# Sync fork feature/edit-portal, build myst + edit-portal, avvia stack.
# Uso da EDIT_REPO (es. ~/docker-vms/Server):
#   ./scripts/deploy-edit-portal.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/mud-dev.sh" deploy-edit
