#!/bin/bash
# Copia (opzionale) e patcha il mondo di produzione in mudroot/lib.
# Gli stub in root del repo non vengono modificati né committati da qui.
#
# Vedi anche: ./scripts/apply-production-world-patch.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH_SCRIPT="$ROOT/scripts/apply-thief-world-patch.sh"
DEST="${MYST_WORLD_DIR:-$ROOT/mudroot/lib}"
SRC="${MYST_WORLD_SRC:-}"
DO_PATCH=1
DO_FLAVOR=0
CHECK_ONLY=0

MYST_FILES=(myst.mob myst.obj myst.wld myst.zon myst.spe myst.shp)

usage() {
  sed -n '2,22p' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --src)
      SRC="$2"
      shift 2
      ;;
    --dest)
      DEST="$2"
      shift 2
      ;;
    --flavor)
      DO_FLAVOR=1
      shift
      ;;
    --no-patch)
      DO_PATCH=0
      shift
      ;;
    --check)
      CHECK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "prepare-mudlib: opzione sconosciuta: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$DEST" ]; then
  mkdir -p "$DEST"
fi

mudlib_present() {
  [ -f "$DEST/myst.mob" ] && [ -f "$DEST/myst.obj" ] && [ -f "$DEST/myst.zon" ]
}

if [ "$CHECK_ONLY" -eq 1 ]; then
  if ! mudlib_present; then
    echo "prepare-mudlib: nessun mondo in $DEST" >&2
    echo "  Copia i myst.* di produzione in mudroot/lib/ (non usare getworldlocal)." >&2
    exit 1
  fi
  if [ "$DO_PATCH" -eq 1 ] && [ -x "$PATCH_SCRIPT" ]; then
    "$PATCH_SCRIPT" --dir "$DEST" --check
  fi
  echo "OK: mondo produzione in $DEST"
  exit 0
fi

if [ -n "$SRC" ]; then
  if [ ! -d "$SRC" ]; then
    echo "prepare-mudlib: MYST_WORLD_SRC non è una directory: $SRC" >&2
    exit 1
  fi
  echo "prepare-mudlib: copia mondo produzione $SRC -> $DEST"
  for f in "${MYST_FILES[@]}"; do
    if [ ! -f "$SRC/$f" ]; then
      echo "prepare-mudlib: manca $SRC/$f" >&2
      exit 1
    fi
    cp -v "$SRC/$f" "$DEST/$f"
  done
fi

if ! mudlib_present; then
  echo "prepare-mudlib: mondo di produzione non trovato in $DEST" >&2
  echo "" >&2
  echo "Gli stub in root (getworldlocal) sono solo per dev — non sono il mondo live." >&2
  echo "Passi:" >&2
  echo "  cp /backup/produzione/myst.* mudroot/lib/" >&2
  echo "  ./scripts/apply-production-world-patch.sh --flavor" >&2
  exit 1
fi

if [ "$DO_PATCH" -eq 1 ]; then
  if [ ! -x "$PATCH_SCRIPT" ]; then
    echo "prepare-mudlib: manca $PATCH_SCRIPT" >&2
    exit 1
  fi
  patch_args=(--dir "$DEST")
  if [ "$DO_FLAVOR" -eq 1 ]; then
    patch_args+=(--flavor)
  fi
  "$PATCH_SCRIPT" "${patch_args[@]}"
else
  echo "prepare-mudlib: patch ladro saltata (--no-patch)"
fi

echo "OK: mondo produzione patchato in $DEST (non committare mudroot/lib/myst.*)"
