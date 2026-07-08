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

THIEF_VNUMS=(18072 18001 18002 18003 18073 18074)
# Vnum di una patch precedente (solo pulizia zone/myst.obj, mai objects/)
LEGACY_THIEF_VNUMS=(18000 18004 18005)
THIEF_VNUM_FIRST=18072
THIEF_VNUM_LAST=18074
# keyword atteso nella riga nome oggetto (myst.obj), per vnum
THIEF_OBJ_KEYWORDS=(
  "toxic extract"
  "nightshade resin"
  "alkali salt"
  "volatile oil"
  "binding agent"
  "glass vial"
)
THIEF_OBJ_COSTS=(80 90 40 50 30 20)
OBJECTS_DIR="$TARGET_DIR/objects"
ACT_THIEF=16777216

HELPTBL_SRC="$ROOT/pages/helptbl"
WIZHELPTBL_SRC="$ROOT/pages/wizhelptbl"
HELPTBL_DST="$TARGET_DIR/helptbl"
WIZHELPTBL_DST="$TARGET_DIR/wizhelptbl"

usage() {
  sed -n '2,12p' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) TARGET_DIR="$2"; shift 2 ;;
    --flavor) DO_FLAVOR=1; shift ;;
    --check) CHECK_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
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
MOB="$TARGET_DIR/myst.mob"
SHP="$TARGET_DIR/myst.shp"

for f in "$OBJ" "$ZON" "$SHP"; do
  if [ ! -f "$f" ]; then
    echo "apply-thief-world-patch: manca $f" >&2
    exit 1
  fi
done

thief_obj_ok() {
  local idx="$1"
  local v="${THIEF_VNUMS[$idx]}"
  local kw="${THIEF_OBJ_KEYWORDS[$idx]}"
  grep -q "^#${v}$" "$OBJ" \
    && awk -v target="$v" -v kw="$kw" '
      $0 == "#" target { show=1 }
      show && index($0, kw) { found=1; exit }
      show && $0 == "~" { exit }
      END { exit(found ? 0 : 1) }
    ' "$OBJ"
}

thief_obj_cost_ok() {
  local idx="$1"
  local v="${THIEF_VNUMS[$idx]}"
  local cost="${THIEF_OBJ_COSTS[$idx]}"
  awk -v target="$v" -v cost="$cost" '
    $0 == "#" target { show=1; costline=-1; next }
    show && /^[0-9]+ [0-9]+ [0-9]+$/ { costline=$2 + 0 }
    show && /^#[0-9]+$/ { exit }
    END { exit(costline == cost ? 0 : 1) }
  ' "$OBJ"
}

thief_objs_complete() {
  local i
  for i in 0 1 2 3 4 5; do
    thief_obj_ok "$i" || return 1
    thief_obj_cost_ok "$i" || return 1
  done
  return 0
}

thief_vnum_has_overlay() {
  local v="$1"
  [ -f "$OBJECTS_DIR/$v" ]
}

thief_vnums_overlay_free() {
  local v
  for v in "${THIEF_VNUMS[@]}"; do
    if thief_vnum_has_overlay "$v"; then
      echo "apply-thief-world-patch: vnum #$v ha overlay ${OBJECTS_DIR}/$v" >&2
      echo "apply-thief-world-patch: NON cancellare objects/ — scegliere altri vnum (vedi world-patches/thief-crafting/OVERLAYS.txt)" >&2
      return 1
    fi
  done
  return 0
}

thief_help_ok() {
  [ -f "$HELPTBL_DST" ] && grep -q 'POCKET SAND SAND' "$HELPTBL_DST"
}

sync_help_tables() {
  if [ ! -f "$HELPTBL_SRC" ]; then
    echo "apply-thief-world-patch: manca $HELPTBL_SRC" >&2
    exit 1
  fi
  sed 's/\r$//' "$HELPTBL_SRC" > "$HELPTBL_DST"
  if [ -f "$WIZHELPTBL_SRC" ]; then
    sed 's/\r$//' "$WIZHELPTBL_SRC" > "$WIZHELPTBL_DST"
  fi
}

thief_obj_strip_vnums() {
  echo "18072 18001 18002 18003 18073 18074 ${LEGACY_THIEF_VNUMS[*]}"
}

sync_thief_obj_definitions() {
  local frag="$PATCH_DIR/myst.obj.fragment"
  local strip_vnums tmp
  if [ ! -f "$frag" ]; then
    echo "apply-thief-world-patch: manca $frag" >&2
    exit 1
  fi
  strip_vnums="$(thief_obj_strip_vnums)"
  tmp="$(mktemp)"
  awk -v frag="$frag" -v strip_vnums="$strip_vnums" '
    function load_strip(    n, parts, i) {
      n = split(strip_vnums, parts, " ")
      for (i = 1; i <= n; i++) {
        if (parts[i] != "") strip[parts[i] + 0] = 1
      }
    }
    function is_strip_vnum(v) {
      return (v in strip)
    }
    BEGIN {
      load_strip()
      split("18072 18001 18002 18003 18073 18074", insert_order, " ")
      while ((getline line < frag) > 0) {
        if (line ~ /^#[0-9]+$/) {
          if (cur_vnum != "") blocks[cur_vnum] = cur_block
          cur_vnum = substr(line, 2) + 0
          cur_block = line "\n"
        }
        else if (cur_vnum != "") {
          cur_block = cur_block line "\n"
        }
      }
      if (cur_vnum != "") blocks[cur_vnum] = cur_block
      close(frag)
    }
    /^#99999$/ {
      skip_block = 0
      for (i = 1; i <= 6; i++) {
        vnum = insert_order[i] + 0
        if (vnum in blocks) printf "%s", blocks[vnum]
      }
      print
      next
    }
    /^#[0-9]+$/ {
      vnum = substr($0, 2) + 0
      if (is_strip_vnum(vnum)) {
        skip_block = 1
        next
      }
      skip_block = 0
      print
      next
    }
    skip_block { next }
    /^%%/ {
      print
      past_eof = 1
      next
    }
    past_eof { next }
    { print }
  ' "$OBJ" > "$tmp"
  mv "$tmp" "$OBJ"
}

thief_objs_before_eof() {
  awk -v strip_vnums="$(thief_obj_strip_vnums)" '
    function load_strip(    n, parts, i) {
      n = split(strip_vnums, parts, " ")
      for (i = 1; i <= n; i++) {
        if (parts[i] != "") strip[parts[i] + 0] = 1
      }
    }
    BEGIN {
      load_strip()
      split("18072 18001 18002 18003 18073 18074", need, " ")
      for (i = 1; i <= 6; i++) want[need[i] + 0] = 1
    }
    /^%%/ { past_eof = 1 }
    /^#[0-9]+$/ {
      vnum = substr($0, 2) + 0
      if (!past_eof && vnum in want) seen[vnum] = 1
    }
    END {
      for (vnum in want) {
        if (!seen[vnum]) exit 1
      }
    }
  ' "$OBJ"
}

vnums_conflict() {
  local i v
  for i in 0 1 2 3 4 5; do
    v="${THIEF_VNUMS[$i]}"
    if grep -q "^#${v}$" "$OBJ" && ! thief_obj_ok "$i"; then
      echo "apply-thief-world-patch: vnum #$v già occupato da altro oggetto" >&2
      awk -v target="$v" '
        $0 == "#" target { show=1 }
        show { print }
        show && $0 == "~" { exit }
      ' "$OBJ" | sed 's/^/  /' >&2
      return 0
    fi
  done
  return 1
}

shops_have_ingredients() {
  local v
  for v in "${THIEF_VNUMS[@]}"; do
    if ! grep -qE "^${v}$" "$SHP"; then
      return 1
    fi
  done
  return 0
}

shops_products_ok() {
  awk '
    function bad_slot(v, expected) {
      return v + 0 != expected
    }
    /^#3005~$/ { shop = 3005; n = 0; next }
    /^#3006~$/ { shop = 3006; n = 0; next }
    shop == 3005 && n < 5 {
      n++
      if (n == 1 && bad_slot($1, 18072)) exit 1
      if (n == 2 && bad_slot($1, 18001)) exit 1
      if (n == 3 && bad_slot($1, 18002)) exit 1
      if (n > 3 && ($1 + 0) != -1) exit 1
      if (n == 5) shop = 0
      next
    }
    shop == 3006 && n < 5 {
      n++
      if (n == 1 && bad_slot($1, 18003)) exit 1
      if (n == 2 && bad_slot($1, 18073)) exit 1
      if (n == 3 && bad_slot($1, 18074)) exit 1
      if (n > 3 && ($1 + 0) != -1) exit 1
      if (n == 5) shop = 0
      next
    }
    END { exit(shop ? 1 : 0) }
  ' "$SHP"
}

reagent_vendors_present() {
  grep -qE 'G 1 18072 0' "$ZON" \
    && grep -qE 'G 1 18074 0' "$ZON" \
    && grep -qE '^M 0 3042 1 3047' "$ZON" \
    && grep -qE '^M 0 3043 1 3003' "$ZON"
}

shop_rooms_ok() {
  awk '
    /^#3005~$/ { shop = 3005; n = 0; next }
    shop == 3005 {
      n++
      if (n == 24 && $1 + 0 != 3047) exit 1
      if (n >= 28) shop = 0
      next
    }
    END { exit(shop ? 1 : 0) }
  ' "$SHP"
}

patch_present() {
  thief_objs_complete && thief_objs_before_eof \
    && thief_vnums_overlay_free \
    && thief_help_ok \
    && shops_have_ingredients && shops_products_ok \
    && reagent_vendors_present && shop_rooms_ok
}

strip_thief_zone_lines() {
  local tmp
  tmp="$(mktemp)"
  awk '
    function is_thief_ing_vnum(v) {
      return v == 18072 || v == 18001 || v == 18002 || v == 18003 || v == 18073 || v == 18074 \
        || v == 18000 || v == 18004 || v == 18005 \
        || (v >= 18500 && v <= 18505)
    }
    function is_ing_line(line,    n, parts, v) {
      if (line ~ /^(G|O) /) {
        n = split(line, parts, " ")
        if (n >= 3) {
          v = parts[3] + 0
          if (is_thief_ing_vnum(v)) return 1
        }
      }
      return 0
    }
    {
      if (is_ing_line($0)) next
      print
    }
  ' "$ZON" > "$tmp"
  mv "$tmp" "$ZON"
}

clean_guild_room_objects() {
  : # tutti gli O ingredienti rimossi da strip_thief_zone_lines
}

remove_act_flag_from_mob() {
  local mob_vnum="$1"
  local flag="$2"
  local tmp
  if [ ! -f "$MOB" ]; then
    return 0
  fi
  tmp="$(mktemp)"
  awk -v mob="#$mob_vnum" -v flag="$flag" '
    function strip_field(field,    n, parts, i, out, cnt) {
      n = split(field, parts, "|")
      out = ""
      cnt = 0
      for (i = 1; i <= n; i++) {
        if (parts[i] == flag || parts[i] == "") continue
        if (cnt == 0) out = parts[i]; else out = out "|" parts[i]
        cnt++
      }
      return out
    }
    $0 == mob { inmob = 1; print; next }
    inmob && /^#/ { inmob = 0 }
    inmob && /^[0-9]/ {
      $1 = strip_field($1)
      $2 = strip_field($2)
      print
      next
    }
    { print }
  ' "$MOB" > "$tmp"
  mv "$tmp" "$MOB"
}

remove_guild_master_thief_flag() {
  # Drunky (#3007), Spanky (#3022), Flasite (#7811) — non devono derubare i PG in gilda/taverna
  local mob
  for mob in 3007 3022 7811; do
    remove_act_flag_from_mob "$mob" "$ACT_THIEF"
  done
}

apply_shop_products() {
  local patch="$PATCH_DIR/myst.shp.products"
  local tmp
  if [ ! -f "$patch" ]; then
    echo "apply-thief-world-patch: manca $patch" >&2
    exit 1
  fi
  tmp="$(mktemp)"
  awk -v patch="$patch" '
    BEGIN {
      while ((getline line < patch) > 0) {
        if (line ~ /^#/ || line ~ /^[[:space:]]*$/) continue
        split(line, kv, ":")
        shop = kv[1]
        n = split(kv[2], adds, ",")
        add_count[shop] = n
        for (i = 1; i <= n; i++) add_vnum[shop, i] = adds[i] + 0
      }
      close(patch)
    }
    /^#[0-9]+~$/ {
      id = substr($0, 2)
      sub(/~$/, "", id)
      print
      if (id in add_count) {
        for (i = 1; i <= 5; i++) {
          getline line
          if (i <= add_count[id]) {
            print add_vnum[id, i]
          }
          else {
            print -1
          }
        }
        next
      }
      next
    }
    { print }
  ' "$SHP" > "$tmp"
  mv "$tmp" "$SHP"
}

fix_shop_rooms() {
  local tmp
  tmp="$(mktemp)"
  awk '
    /^#3005~$/ { in_shop = 1; shop_line = 0; print; next }
    in_shop {
      shop_line++
      if (shop_line == 24 && $1 + 0 == 3018) {
        $1 = 3047
      }
      print
      if (shop_line >= 28) {
        in_shop = 0
      }
      next
    }
    { print }
  ' "$SHP" > "$tmp"
  mv "$tmp" "$SHP"
}

apply_reagent_vendor_zone() {
  local frag="$PATCH_DIR/myst.zon.reagent-vendors.fragment"
  local tmp
  if [ ! -f "$frag" ]; then
    echo "apply-thief-world-patch: manca $frag" >&2
    exit 1
  fi
  if reagent_vendors_present; then
    return 0
  fi
  tmp="$(mktemp)"
  awk -v frag="$frag" '
    BEGIN {
      while ((getline line < frag) > 0) {
        if (line ~ /^#/ || line ~ /^[[:space:]]*$/) continue
        lines[++n] = line
      }
      close(frag)
    }
    /^M 0 3073 1 3003/ && !done {
      print
      for (i = 1; i <= n; i++) print lines[i]
      done = 1
      next
    }
    { print }
  ' "$ZON" > "$tmp"
  mv "$tmp" "$ZON"
}

if [ "$CHECK_ONLY" -eq 1 ]; then
  if patch_present; then
    echo "OK: patch crafting ladro presente in $TARGET_DIR"
    exit 0
  fi
  echo "MISSING: patch crafting ladro assente in $TARGET_DIR" >&2
  exit 1
fi

echo "apply-thief-world-patch: pulizia reset gilde / ACT_THIEF (Drunky, Spanky, Flasite)"
strip_thief_zone_lines
clean_guild_room_objects
remove_guild_master_thief_flag

if ! thief_vnums_overlay_free; then
  exit 1
fi

echo "apply-thief-world-patch: myst.obj (ingredienti ladro, sync definizioni)"
sync_thief_obj_definitions

echo "apply-thief-world-patch: helptbl (help skill ladro in mudroot/lib — myst legge da DATA_DIR)"
sync_help_tables

if ! shops_products_ok; then
  echo "apply-thief-world-patch: myst.shp (prodotti negozi reagenti #3005/#3006)"
  apply_shop_products
else
  echo "apply-thief-world-patch: myst.shp prodotti reagenti già corretti"
fi

if ! shop_rooms_ok; then
  echo "apply-thief-world-patch: myst.shp (stanza negozio #3005 → 3047)"
  fix_shop_rooms
fi

if ! reagent_vendors_present; then
  echo "apply-thief-world-patch: myst.zon (spawn negozianti reagenti)"
  apply_reagent_vendor_zone
else
  echo "apply-thief-world-patch: myst.zon negozianti reagenti già presenti"
fi

if [ "$DO_FLAVOR" -eq 1 ] && [ -f "$WLD" ]; then
  if grep -q 'reagenti da ladro' "$WLD"; then
    echo "apply-thief-world-patch: flavor myst.wld già presente"
  else
    echo "apply-thief-world-patch: myst.wld (testo gilde ladro)"
    tmp_wld="$(mktemp)"
    awk '
      /^#3076$/ { in3076 = 1; print; next }
      in3076 {
        if ($0 == "~" && !done3076) {
          print "Nell aria aleggia un debole odore di reagenti alchemici."
          done3076 = 1
          in3076 = 0
        }
        print
        next
      }
      /^#7828$/ { in7828 = 1; print; next }
      in7828 {
        if ($0 == "~" && !done7828) {
          print "Senti un tenue odore di essenze e polveri da laboratorio."
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
if ! thief_objs_complete; then
  echo "apply-thief-world-patch: myst.obj ingredienti ladro incompleti o costo errato" >&2
  exit 1
fi
if ! thief_objs_before_eof; then
  echo "apply-thief-world-patch: ingredienti ladro assenti o dopo %% in myst.obj (non caricati al boot)" >&2
  exit 1
fi
if ! thief_help_ok; then
  echo "apply-thief-world-patch: mudroot/lib/helptbl senza help skill ladro (myst fa chdir in DATA_DIR)" >&2
  exit 1
fi
if ! thief_vnums_overlay_free; then
  echo "apply-thief-world-patch: vnum ingredienti collidono con overlay objects/" >&2
  exit 1
fi
if ! shops_products_ok; then
  echo "apply-thief-world-patch: myst.shp prodotti negozi #3005/#3006 non corretti" >&2
  exit 1
fi
if ! reagent_vendors_present; then
  echo "apply-thief-world-patch: myst.zon senza reset negozianti reagenti" >&2
  exit 1
fi
if ! shop_rooms_ok; then
  echo "apply-thief-world-patch: myst.shp negozio #3005 non punta a stanza 3047" >&2
  exit 1
fi
echo "OK: ingredienti ${THIEF_VNUM_FIRST}-${THIEF_VNUM_LAST} in myst.obj; vendita in myst.shp"
echo "  Negozio #3005 — L'Attendente mago, stanza 3047 (torre della magia): estratto, resina, sale"
echo "  Negozio #3006 — L'Attendente, stanza 3003 (ingresso cappella, est piazza): olio, legante, fiale"
echo "  (list solo dal negoziante con oggetti in inventario — non Tricky, non l'Attendente gilde 3061)"
echo "Prossimo passo: SERVER_PORT=4003 ./docker-run.sh up -d consumer"
