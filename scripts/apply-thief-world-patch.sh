#!/bin/bash
# Applica al mudlib di produzione solo le modifiche mondo per il crafting ladro.
#
# Applica solo i fragment ladro su myst.* già in mudroot/lib (tipicamente produzione).
# Gli stub in root del repo non vanno patchati da qui — usa APPLY_THIEF_WORLD_PATCH=1 ./getworldlocal
# Produzione: ./scripts/apply-production-world-patch.sh [--flavor]
#
# Opzioni:
#   --dir PATH   directory con myst.obj / myst.zon / myst.wld (default: mudroot/lib)
#   --flavor     aggiorna anche le descrizioni stanza 3076 e 7828 in myst.wld
#   --check      verifica che la patch sia presente, senza modificare file
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH_DIR="$ROOT/world-patches/thief-crafting"
TARGET_DIR="$ROOT/mudroot/lib"
DO_FLAVOR=0
CHECK_ONLY=0

# Allineati a world-patches/thief-crafting/VNUMS.txt (produzione: 18500-18505 occupati)
THIEF_VNUMS=(18000 18001 18002 18003 18004 18005)
THIEF_VNUM_FIRST=18000
THIEF_VNUM_LAST=18005
THIEF_MARKER_OBJ='toxic extract estratto tossico'
THIEF_MARKER_ZON='018000 \[un estratto tossico\] dato al MOB 003022'

usage() {
  sed -n '2,12p' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      TARGET_DIR="$2"
      shift 2
      ;;
    --flavor)
      DO_FLAVOR=1
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
      echo "apply-thief-world-patch: opzione sconosciuta: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

OBJ="$TARGET_DIR/myst.obj"
ZON="$TARGET_DIR/myst.zon"
WLD="$TARGET_DIR/myst.wld"

for f in "$OBJ" "$ZON"; do
  if [ ! -f "$f" ]; then
    echo "apply-thief-world-patch: manca $f" >&2
    exit 1
  fi
done

patch_present() {
  grep -q "^#${THIEF_VNUM_FIRST}$" "$OBJ" \
    && grep -qF "$THIEF_MARKER_OBJ" "$OBJ" \
    && grep -qF '018000 [un estratto tossico] dato al MOB 003022' "$ZON" \
    && grep -qF '018000 [un estratto tossico] dato al MOB 007811' "$ZON"
}

vnums_conflict() {
  local v
  for v in "${THIEF_VNUMS[@]}"; do
    if grep -q "^#${v}$" "$OBJ"; then
      if ! grep -qF "$THIEF_MARKER_OBJ" "$OBJ" || ! grep -A6 "^#${v}$" "$OBJ" | grep -qF "$THIEF_MARKER_OBJ"; then
        echo "apply-thief-world-patch: vnum #$v già occupato in myst.obj" >&2
        awk -v target="$v" '
          $0 == "#" target { show=1 }
          show { print }
          show && $0 == "~" { exit }
        ' "$OBJ" | sed 's/^/  /' >&2
        return 0
      fi
    fi
  done
  return 1
}

if [ "$CHECK_ONLY" -eq 1 ]; then
  if patch_present; then
    echo "OK: patch crafting ladro presente in $TARGET_DIR"
    exit 0
  fi
  echo "MISSING: patch crafting ladro assente in $TARGET_DIR" >&2
  exit 1
fi

if patch_present; then
  echo "apply-thief-world-patch: già applicata in $TARGET_DIR"
else
  if vnums_conflict; then
    echo "apply-thief-world-patch: scegli altri vnum liberi (vedi world-reference/snippets/vnum-suggestions.txt)" >&2
    exit 1
  fi
  echo "apply-thief-world-patch: myst.obj (#${THIEF_VNUM_FIRST}-#${THIEF_VNUM_LAST})"
  tmp_obj="$(mktemp)"
  awk -v frag="$PATCH_DIR/myst.obj.fragment" '
    BEGIN { while ((getline line < frag) > 0) block = block line ORS; close(frag) }
    /^#99999$/ && !done { printf "%s", block; done = 1 }
    { print }
  ' "$OBJ" > "$tmp_obj"
  mv "$tmp_obj" "$OBJ"

  insert_zon_block() {
    local anchor="$1"
    local fragment="$2"
    local tmp_zon
    tmp_zon="$(mktemp)"
    awk -v anchor="$anchor" -v frag="$fragment" '
      BEGIN { while ((getline line < frag) > 0) block = block line ORS; close(frag) }
      index($0, anchor) {
        print
        if (!done) { printf "%s", block; done = 1 }
        next
      }
      { print }
    ' "$ZON" > "$tmp_zon"
    if ! grep -qF "$(head -1 "$fragment")" "$tmp_zon"; then
      echo "apply-thief-world-patch: anchor non trovato in myst.zon: $anchor" >&2
      rm -f "$tmp_zon"
      exit 1
    fi
    mv "$tmp_zon" "$ZON"
  }

  echo "apply-thief-world-patch: myst.zon (Spanky / gilda Myst)"
  insert_zon_block "M 0 3022 1 3076" "$PATCH_DIR/myst.zon.after-spanky.fragment"

  echo "apply-thief-world-patch: myst.zon (Flasite / Colosseo)"
  insert_zon_block "M 0 7811 1 7828" "$PATCH_DIR/myst.zon.after-flasite.fragment"
fi

if [ "$DO_FLAVOR" -eq 1 ]; then
  if [ ! -f "$WLD" ]; then
    echo "apply-thief-world-patch: --flavor richiede $WLD" >&2
    exit 1
  fi
  if grep -q 'estratto tossico' "$WLD"; then
    echo "apply-thief-world-patch: flavor myst.wld già presente"
  else
    echo "apply-thief-world-patch: myst.wld (descrizioni opzionali gilde ladro)"
    tmp_wld="$(mktemp)"
    awk '
      /^#3076$/ { in3076 = 1; print; next }
      in3076 {
        if ($0 == "~" && !done3076) {
          print "Sul piano ci sono $c0010fiale di vetro$c0007, $c0010estratto tossico$c0007,"
          print "$c0010resina di morella$c0007 e altri reagenti da ladro."
          done3076 = 1
          in3076 = 0
        }
        print
        next
      }
      /^#7828$/ { in7828 = 1; print; next }
      in7828 {
        if ($0 == "~" && !done7828) {
          print "Sul tavolo noti $c0010fiale$c0007, $c0010reagenti alchemici$c0007 e barattoli"
          print "per la preparazione di veleni e fiale."
          done7828 = 1
          in7828 = 0
        }
        print
        next
      }
      { print }
    ' "$WLD" > "$tmp_wld"
    mv "$tmp_wld" "$WLD"
  fi
fi

echo "apply-thief-world-patch: verifica"
if [ "$(grep -c "^#${THIEF_VNUM_LAST}$" "$OBJ" || true)" -ne 1 ]; then
  echo "apply-thief-world-patch: myst.obj non contiene esattamente #${THIEF_VNUM_LAST}" >&2
  exit 1
fi
if [ "$(grep -cF '018000 [un estratto tossico] dato al MOB 003022' "$ZON" || true)" -ne 1 ]; then
  echo "apply-thief-world-patch: myst.zon reset Spanky mancante" >&2
  exit 1
fi
if [ "$(grep -cF '018000 [un estratto tossico] dato al MOB 007811' "$ZON" || true)" -ne 1 ]; then
  echo "apply-thief-world-patch: myst.zon reset Flasite mancante" >&2
  exit 1
fi
echo "OK: ingredienti ${THIEF_VNUM_FIRST}-${THIEF_VNUM_LAST} e reset gilde ladro applicati in $TARGET_DIR"
echo "Prossimo passo: SERVER_PORT=4003 ./docker-run.sh up -d consumer"
