#!/bin/bash
# Diagnostica negozi reagenti ladro (#3005 torre, #3006 cappella). Solo lettura.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${DATA_DIR:-$ROOT/mudroot/lib}"
OBJ="$DATA_DIR/myst.obj"
SHP="$DATA_DIR/myst.shp"
ZON="$DATA_DIR/myst.zon"
OBJECTS_DIR="$DATA_DIR/objects"

# Allineato a scripts/apply-thief-world-patch.sh
declare -a VNUMS=(18072 18001 18002 18003 18073 18074)
declare -a NAMES=(
  "estratto tossico (toxic extract)"
  "resina morella (nightshade resin)"
  "sale alcalino (alkali salt)"
  "olio volatile (volatile oil)"
  "agente legante (binding agent)"
  "fiala vetro (glass vial)"
)
declare -a KEYWORDS=(
  "toxic extract"
  "nightshade resin"
  "alkali salt"
  "volatile oil"
  "binding agent"
  "glass vial"
)
declare -a COSTS=(80 90 40 50 30 20)
LEGACY_VNUMS=(18000 18004 18005)

fail=0

echo "=== Verifica negozi reagenti ladro ==="
echo "DATA_DIR=$DATA_DIR"
echo ""

obj_cost() {
  local v="$1"
  awk -v target="$v" '
    $0 == "#" target { show=1; costline=-1; next }
    show && /^[0-9]+ [0-9]+ [0-9]+$/ { costline=$2 + 0 }
    show && /^#[0-9]+$/ { exit }
    END { print costline + 0 }
  ' "$OBJ"
}

obj_has_keyword() {
  local v="$1" kw="$2"
  awk -v target="$v" -v kw="$kw" '
    $0 == "#" target { show=1 }
    show && index($0, kw) { found=1; exit }
    show && $0 == "~" { exit }
    END { exit(found ? 0 : 1) }
  ' "$OBJ"
}

echo "--- myst.shp (prodotti negozio) ---"
for shop in 3005 3006; do
  echo -n "Negozio #$shop: "
  awk -v shop="$shop" '
    $0 == "#" shop "~" { on = 1; n = 0; next }
    on && ++n <= 5 { printf "%s ", $1; if (n == 5) print "" }
    on && n >= 5 { on = 0 }
  ' "$SHP"
done
echo "Atteso #3005: 18072 18001 18002 | #3006: 18003 18073 18074"
if awk '
  /^#3005~$/ { s=3005; n=0; next }
  s==3005 && ++n<=3 { if (n==1 && $1!=18072) e=1; if (n==2 && $1!=18001) e=1; if (n==3 && $1!=18002) e=1; if (n==3) s=0 }
  /^#3006~$/ { s=3006; n=0; next }
  s==3006 && ++n<=3 { if (n==1 && $1!=18003) e=1; if (n==2 && $1!=18073) e=1; if (n==3 && $1!=18074) e=1 }
  END { exit(e ? 1 : 0) }
' "$SHP" 2>/dev/null; then
  echo "OK  myst.shp prodotti reagenti"
else
  echo "FAIL myst.shp — esegui: ./scripts/apply-production-world-patch.sh"
  fail=1
fi
echo ""

echo "--- myst.obj + objects/ (overlay) ---"
for i in 0 1 2 3 4 5; do
  v="${VNUMS[$i]}"
  name="${NAMES[$i]}"
  kw="${KEYWORDS[$i]}"
  cost="${COSTS[$i]}"
  if [ ! -f "$OBJ" ]; then
    echo "FAIL manca $OBJ"
    fail=1
    continue
  fi
  if ! grep -q "^#${v}$" "$OBJ"; then
    echo "FAIL #$v $name — assente in myst.obj"
    fail=1
    continue
  fi
  if ! obj_has_keyword "$v" "$kw"; then
    echo "FAIL #$v $name — keyword errata in myst.obj"
    fail=1
    continue
  fi
  got_cost="$(obj_cost "$v")"
  if [ "$got_cost" != "$cost" ]; then
    echo "WARN #$v $name — costo myst.obj=$got_cost (atteso $cost)"
  fi
  if [ -f "$OBJECTS_DIR/$v" ]; then
    echo "FAIL #$v $name — overlay ${OBJECTS_DIR}/$v (vnum non utilizzabile; NON cancellare overlay)"
    fail=1
  elif awk -v target="$v" '
    /^%%/ { past_eof = 1 }
    $0 == "#" target {
      if (past_eof) { bad = 1; exit }
      found = 1
      exit
    }
    END { exit((found && !bad) ? 0 : 1) }
  ' "$OBJ"; then
    echo "OK  #$v $name"
  else
    echo "FAIL #$v $name — assente o dopo %% in myst.obj (il boot ignora oggetti dopo %% )"
    fail=1
  fi
done
for v in "${LEGACY_VNUMS[@]}"; do
  if [ -f "$OBJECTS_DIR/$v" ]; then
    echo "INFO legacy overlay ${OBJECTS_DIR}/$v (normale in produzione — non usare per reagenti ladro)"
  fi
done
echo ""

echo "--- myst.zon (reset G sui negozianti) ---"
for v in 18072 18001 18002 18003 18073 18074; do
  if grep -qE "G 1 ${v} 0" "$ZON" 2>/dev/null; then
    echo "OK  G 1 $v 0"
  else
    echo "FAIL manca G 1 $v 0 in myst.zon"
    fail=1
  fi
done
for v in "${LEGACY_VNUMS[@]}"; do
  if grep -qE "G 1 ${v} 0" "$ZON" 2>/dev/null; then
    echo "WARN ancora presente G 1 $v 0 (vnum vecchio) — riesegui patch"
    fail=1
  fi
done
echo ""

echo "--- helptbl (myst legge mudroot/lib/helptbl dopo chdir -d) ---"
if [ -f "$DATA_DIR/helptbl" ]; then
  if grep -q 'POCKET SAND SAND' "$DATA_DIR/helptbl" 2>/dev/null; then
    echo "OK  helptbl con help skill ladro (POCKET SAND)"
  else
    echo "FAIL mudroot/lib/helptbl vecchio — manca help ladro; riesegui patch"
    fail=1
  fi
else
  echo "FAIL manca $DATA_DIR/helptbl"
  fail=1
fi
echo ""

echo "--- Binario myst ---"
if [ -x "$ROOT/mudroot/myst" ]; then
  echo "OK  mudroot/myst presente ($(stat -c '%y' "$ROOT/mudroot/myst" 2>/dev/null || stat -f '%Sm' "$ROOT/mudroot/myst"))"
  echo "    Dopo git pull con fix shop.cpp, ricompila:"
  echo "    ./docker-run.sh run --rm consumer ./build.sh sirio-docker"
else
  echo "WARN mudroot/myst assente — ricompila"
fi
echo ""

echo "--- Sintomo tipico se manca qualcosa ---"
echo "  Solo olio in cappella + resina/sale in torre = #18072/#18073/#18074 dopo %% in myst.obj"
echo "  oppure vnum vecchi (18000/18004/18005 con overlay) / patch non applicata / consumer non riavviato"
echo ""

if [ "$fail" -eq 0 ]; then
  echo "OK: dati mondo coerenti. Se in gioco list è ancora sbagliato:"
  echo "  1) Ricompila myst (se non fatto dopo ultimo git pull)"
  echo "  2) SERVER_PORT=4003 ./docker-run.sh down && ./docker-run.sh up -d"
  exit 0
fi

echo "FAIL: correggi con git pull && ./scripts/apply-production-world-patch.sh"
echo "      poi riavvio completo del consumer (obbligatorio per myst.shp)"
exit 1
