#!/bin/bash
# Estrae da mudroot/lib (o MYST_WORLD_SRC) snippet committabili per agenti e patch.
#
# Uso:
#   ./scripts/export-production-world-reference.sh
#   ./scripts/export-production-world-reference.sh --src /path/produzione
#   ./scripts/export-production-world-reference.sh --full-copy
#
# Output: world-reference/snippets/  (in git)
#         world-reference/production/ (solo con --full-copy, gitignored)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${MYST_WORLD_SRC:-$ROOT/mudroot/lib}"
OUT_SNIP="$ROOT/world-reference/snippets"
OUT_FULL="$ROOT/world-reference/production"
FULL_COPY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --src) SRC="$2"; shift 2 ;;
    --full-copy) FULL_COPY=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "export-production-world-reference: opzione sconosciuta: $1" >&2
      exit 1
      ;;
  esac
done

MYST_FILES=(myst.mob myst.obj myst.wld myst.zon myst.spe myst.shp)
for f in "${MYST_FILES[@]}"; do
  if [ ! -f "$SRC/$f" ]; then
    echo "export-production-world-reference: manca $SRC/$f" >&2
    echo "  Copia prima il mondo di produzione in mudroot/lib/" >&2
    exit 1
  fi
done

mkdir -p "$OUT_SNIP"

{
  echo "generated_at=$(date -Is)"
  echo "source_dir=$SRC"
  for f in "${MYST_FILES[@]}"; do
    echo "file $f size=$(wc -c <"$SRC/$f") lines=$(wc -l <"$SRC/$f")"
  done
} >"$OUT_SNIP/MANIFEST.txt"

# Oggetti attorno ai vnum ladro (default 18500-18505)
awk '
  /^#[0-9]+$/ {
    if (cur ~ /^#/) { objs[cur] = block }
    cur = $0
    block = $0 ORS
    next
  }
  { block = block $0 ORS }
  END {
    if (cur ~ /^#/) objs[cur] = block
    for (v = 18490; v <= 18520; v++) {
      key = "#" v
      if (key in objs) print objs[key]
      else print key "\n(vnum assente)\n~\n"
    }
  }
' "$SRC/myst.obj" >"$OUT_SNIP/obj-thief-vnum-window.txt"

# Conflitto esplicito sui 6 vnum ingredienti
{
  echo "# Stato vnum ingredienti ladro (attesi 18500-18505 in codice)"
  for v in 18500 18501 18502 18503 18504 18505; do
    if grep -q "^#$v$" "$SRC/myst.obj"; then
      echo "OCCUPIED #$v"
      awk -v target="$v" '
        $0 == "#" target { show=1 }
        show { print }
        show && $0 == "~" { exit }
      ' "$SRC/myst.obj" | sed 's/^/  /'
    else
      echo "FREE #$v"
    fi
    echo ""
  done
} >"$OUT_SNIP/obj-thief-vnum-status.txt"

# Suggerimenti: ultimi vnum usati e primo blocco libero di 6 consecutivi sopra 18000
awk '
  /^#[0-9]+$/ {
    gsub(/^#/, "", $0)
    used[$0] = 1
    if ($0 > max) max = $0
  }
  END {
    print "max_object_vnum=" max
    print ""
    print "# Primi blocchi liberi di 6 vnum consecutivi (>= 18000):"
    found = 0
    for (start = 18000; start <= max + 50 && found < 5; start++) {
      ok = 1
      for (i = 0; i < 6; i++) {
        if ((start + i) in used) { ok = 0; break }
      }
      if (ok) {
        printf "  %d-%d\n", start, start + 5
        found++
      }
    }
    if (found == 0) print "  (nessun blocco trovato — estendi ricerca nello script)"
  }
' "$SRC/myst.obj" >"$OUT_SNIP/vnum-suggestions.txt"

# Indice compatto: ogni vnum oggetto (per grep veloce da agent)
awk '/^#[0-9]+$/{print}' "$SRC/myst.obj" >"$OUT_SNIP/obj-vnum-index.txt"

# Zone: contesto Spanky / Flasite
extract_zon_context() {
  local anchor="$1"
  local out="$2"
  local line
  line="$(grep -nF "$anchor" "$SRC/myst.zon" | head -1 | cut -d: -f1 || true)"
  if [ -z "$line" ]; then
    echo "ANCHOR NOT FOUND: $anchor" >"$out"
    return
  fi
  local start=$((line - 3))
  [ "$start" -lt 1 ] && start=1
  sed -n "${start},$((line + 25))p" "$SRC/myst.zon" >"$out"
}

extract_zon_context "M 0 3022 1 3076" "$OUT_SNIP/zone-spanky.context.txt"
extract_zon_context "M 0 7811 1 7828" "$OUT_SNIP/zone-flasite.context.txt"

# Stanze gilda (se presenti)
for room in 3076 7828; do
  awk -v r="$room" '
    $0 == "#" r { show=1 }
    show { print }
    show && $0 == "~" { exit }
  ' "$SRC/myst.wld" >"$OUT_SNIP/room-${room}.wld.txt" 2>/dev/null || true
done

# Riga reset ingredienti già presenti?
{
  echo "grep 18500 in myst.zon:"
  grep -n '18500' "$SRC/myst.zon" || echo "(nessuna)"
  echo ""
  echo "grep estratto tossico in myst.obj:"
  grep -n 'estratto tossico' "$SRC/myst.obj" || echo "(nessuna)"
} >"$OUT_SNIP/patch-thief-already-applied.txt"

if [ "$FULL_COPY" -eq 1 ]; then
  mkdir -p "$OUT_FULL"
  for f in "${MYST_FILES[@]}"; do
    cp -v "$SRC/$f" "$OUT_FULL/$f"
  done
  echo "full_copy_dir=$OUT_FULL" >>"$OUT_SNIP/MANIFEST.txt"
fi

echo "OK: snippet in $OUT_SNIP"
echo "  Leggi: obj-thief-vnum-status.txt, vnum-suggestions.txt"
if [ "$FULL_COPY" -eq 1 ]; then
  echo "  Copia completa (gitignored): $OUT_FULL"
fi
