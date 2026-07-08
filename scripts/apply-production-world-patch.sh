#!/bin/bash
# Applica la patch ladro al mondo di PRODUZIONE già presente in mudroot/lib.
#
# Non tocca i myst.* stub in root (mondo progetto in git).
# Non eseguire getworldlocal dopo aver copiato il mondo di produzione:
# sovrascriveresti i file buoni con gli stub monchi.
#
# Uso:
#   cp /path/produzione/myst.{mob,obj,wld,zon,spe,shp} mudroot/lib/
#   ./scripts/apply-production-world-patch.sh [--flavor]
#
# Oppure copia + patch in un passo:
#   MYST_WORLD_SRC=/path/produzione ./scripts/apply-production-world-patch.sh
#
# Opzioni: come apply-thief-world-patch.sh (--flavor, --check, --src, --dest)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MYST_WORLD_DIR="${MYST_WORLD_DIR:-$ROOT/mudroot/lib}"
exec "$ROOT/scripts/prepare-mudlib.sh" "$@"
