#!/bin/bash
# Permessi scrittura edit_system.json (staff portale).
set -euo pipefail
cd "$(dirname "$0")/.."
CFG="mudroot/lib/edit_system.json"
if [ ! -f "$CFG" ] && [ -f Confs/edit_system.default.json ]; then
	cp Confs/edit_system.default.json "$CFG"
fi
chmod u+rw "$CFG" 2>/dev/null || sudo chmod u+rw "$CFG"
ls -la "$CFG"
echo "OK: $CFG scrivibile. Riavvia myst se il salvataggio fallisce ancora: ./scripts/mud-dev.sh rebuild-myst"
