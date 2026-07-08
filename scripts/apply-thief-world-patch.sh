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

THIEF_VNUMS=(18000 18001 18002 18003 18004 18005)
THIEF_VNUM_FIRST=18000
THIEF_VNUM_LAST=18005
# keyword atteso nella riga nome oggetto (myst.obj), per vnum
THIEF_OBJ_KEYWORDS=(
  "toxic extract"
  "nightshade resin"
  "alkali salt"
  "volatile oil"
  "binding agent"
  "glass vial"
)
ACT_THIEF=16777216

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

thief_objs_present() {
  local i
  for i in 0 1 2 3 4 5; do
    thief_obj_ok "$i" || return 1
  done
  return 0
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

patch_present() {
  thief_objs_present && shops_have_ingredients
}

strip_thief_zone_lines() {
  local tmp
  tmp="$(mktemp)"
  awk '
    function is_ing_line(line,    i, v) {
      if (line ~ /^O 0 /) {
        v = $2 + 0
        if (v >= 18000 && v <= 18005) return 1
        if (v >= 18500 && v <= 18505) return 1
      }
      if (line !~ /^[GO] /) return 0
      for (i = 0; i < 6; i++) {
        v = 18000 + i
        if (index(line, " " v " ")) return 1
      }
      for (i = 0; i < 6; i++) {
        v = 18500 + i
        if (index(line, " " v " ")) return 1
      }
      if (line ~ /^G 1 (1800|1850)/) return 1
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
    function shop_has_vnum(v,    i) {
      for (i = 1; i <= 5; i++) {
        if (cur_prod[i] == v) return 1
      }
      return 0
    }
    /^#[0-9]+~$/ {
      id = substr($0, 2)
      sub(/~$/, "", id)
      print
      if (id in add_count) {
        for (i = 1; i <= 5; i++) {
          getline line
          cur_prod[i] = line + 0
        }
        ai = 1
        for (i = 1; i <= 5; i++) {
          if (cur_prod[i] == -1 && ai <= add_count[id]) {
            while (ai <= add_count[id] && shop_has_vnum(add_vnum[id, ai])) ai++
            if (ai <= add_count[id]) {
              cur_prod[i] = add_vnum[id, ai]
              ai++
            }
          }
        }
        for (i = 1; i <= 5; i++) print cur_prod[i]
        next
      }
      next
    }
    { print }
  ' "$SHP" > "$tmp"
  mv "$tmp" "$SHP"
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

if ! thief_objs_present; then
  if vnums_conflict; then
    echo "apply-thief-world-patch: vnum in conflitto — vedi world-reference/snippets/vnum-suggestions.txt" >&2
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
else
  echo "apply-thief-world-patch: myst.obj ingredienti già presenti"
fi

if ! shops_have_ingredients; then
  echo "apply-thief-world-patch: myst.shp (mercanti Myst)"
  apply_shop_products
else
  echo "apply-thief-world-patch: myst.shp già aggiornato"
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
if ! thief_objs_present; then
  echo "apply-thief-world-patch: myst.obj incompleto" >&2
  exit 1
fi
if ! shops_have_ingredients; then
  echo "apply-thief-world-patch: myst.shp senza ingredienti 18000-18005" >&2
  exit 1
fi
echo "OK: ingredienti ${THIEF_VNUM_FIRST}-${THIEF_VNUM_LAST} in myst.obj; vendita in myst.shp"
echo "  Negozio #3005 (stanza 3018): +estratto, resina, sale"
echo "  Negozio #3006 (stanza 3003): +olio, legante, fiale"
echo "  (solo slot liberi — nessun oggetto a terra)"
echo "Prossimo passo: SERVER_PORT=4003 ./docker-run.sh up -d consumer"
