"""Decode Myst object flags, values and affects like the in-game identify output."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]
LIM_ITEM_COST_MIN = 20000

ITEM_TYPES = {
    0: "UNDEFINED",
    1: "LIGHT",
    2: "SCROLL",
    3: "WAND",
    4: "STAFF",
    5: "WEAPON",
    6: "FIRE WEAPON",
    7: "MISSILE",
    8: "TREASURE",
    9: "ARMOR",
    10: "POTION",
    11: "WORN",
    12: "OTHER",
    13: "TRASH",
    14: "TRAP",
    15: "CONTAINER",
    16: "NOTE",
    17: "LIQUID CONTAINER",
    18: "KEY",
    19: "FOOD",
    20: "MONEY",
    21: "PEN",
    22: "BOAT",
    23: "AUDIO",
    24: "BOARD",
    25: "TREE",
    26: "ROCK",
    27: "MINED GEM",
    28: "MINED MINERAL",
    29: "BAR",
    30: "JEWEL",
}

EXTRA_BITS = [
    "GLOW", "HUM", "METAL", "MINERAL", "ORGANIC", "INVISIBLE", "MAGIC", "NODROP",
    "BLESS", "ANTI-GOOD", "ANTI-EVIL", "ANTI-NEUTRAL", "ANTI-CLERIC", "ANTI-MAGE",
    "ANTI-THIEF", "ANTI-WARRIOR", "BRITTLE", "RESISTANT", "ARTIFACT", "ANTI-MEN",
    "ANTI-WOMEN", "ANTI-SUN", "ANTI-BARBARIAN", "ANTI-RANGER", "ANTI-PALADIN",
    "ANTI-PSIONIST", "ANTI-MONK", "ANTI-DRUID", "ONLY-CLASS", "DIG", "SCYTHE",
    "ANTI-SORCERER",
]

EXTRA_BITS2 = [
    "QUEST-ITEM", "EDIT", "NO-LOCATE", "PERSONAL", "HAS-GEMS", "NO-PRINCE", "ONLY-PRINCE",
]

APPLY_TYPES = [
    "NONE", "STR", "DEX", "INT", "WIS", "CON", "CHR", "SEX", "LEVEL", "AGE",
    "CHAR_WEIGHT", "CHAR_HEIGHT", "MANA", "HIT", "MOVE", "GOLD", "EXP", "ARMOR",
    "HITROLL", "DAMROLL", "SAVING_PARA", "SAVING_ROD", "SAVING_PETRI", "SAVING_BREATH",
    "SAVING_SPELL", "SAVING_ALL", "RESISTANCE", "SUSCEPTIBILITY", "IMMUNITY",
    "SPELL AFFECT", "WEAPON SPELL", "EAT SPELL", "BACKSTAB", "KICK", "SNEAK", "HIDE",
    "BASH", "PICK", "STEAL", "TRACK", "HIT-N-DAM", "SPELLFAIL", "ATTACKS", "HASTE",
    "SLOW", "SPELL AFFECT 2", "FIND-TRAPS", "RIDE", "RACE-SLAYER", "ALIGN-SLAYER",
    "MANA-REGEN", "HIT-REGEN", "MOVE-REGEN", "MOD-THIRST", "MOD-HUNGER", "MOD-DRUNK",
    "T_STR", "T_INT", "T_DEX", "T_WIS", "T_CON", "T_CHR", "T_HPS", "T_MOVE", "T_MANA",
    "SPELLPOWER", "HIT-N-SP",
]

IMMUNITY_NAMES = [
    "FIRE", "COLD", "ELECTRICITY", "ENERGY", "BLUNT", "PIERCE", "SLASH", "ACID",
    "POISON", "DRAIN", "SLEEP", "CHARM", "HOLD", "NON-MAGIC", "+1", "+2", "+3", "+4",
]

WEAPON_TYPES = [
    "SMITE", "STAB", "WHIP", "SLASH", "SMASH", "CLEAVE", "CRUSH", "BLUDGEON", "CLAW",
    "BITE", "STING", "PIERCE", "BLAST", "RANGE_WEAPON",
]

ALIGNMENT_FLAGS = {"ANTI-GOOD", "ANTI-EVIL", "ANTI-NEUTRAL"}
GENDER_FLAGS = {"ANTI-MEN", "ANTI-WOMEN"}

# Bit ITEM_ANTI_* / ONLY_CLASS (autoenums.hpp) — allineati a GetItemClassRestrictions()
ITEM_ANTI_CLERIC = 4096
ITEM_ANTI_MAGE = 8192
ITEM_ANTI_THIEF = 16384
ITEM_ANTI_FIGHTER = 32768
ITEM_ANTI_BARBARIAN = 4194304
ITEM_ANTI_RANGER = 8388608
ITEM_ANTI_PALADIN = 16777216
ITEM_ANTI_PSI = 33554432
ITEM_ANTI_MONK = 67108864
ITEM_ANTI_DRUID = 134217728
ITEM_ANTI_SORCERER = 2147483648
ITEM_ONLY_CLASS = 268435456

CLASS_ANTI_BITS = [
    (ITEM_ANTI_MAGE, "MAGE"),
    (ITEM_ANTI_CLERIC, "CLERIC"),
    (ITEM_ANTI_FIGHTER, "WARRIOR"),
    (ITEM_ANTI_THIEF, "THIEF"),
    (ITEM_ANTI_DRUID, "DRUID"),
    (ITEM_ANTI_MONK, "MONK"),
    (ITEM_ANTI_BARBARIAN, "BARBARIAN"),
    (ITEM_ANTI_SORCERER, "SORCERER"),
    (ITEM_ANTI_PALADIN, "PALADIN"),
    (ITEM_ANTI_RANGER, "RANGER"),
    (ITEM_ANTI_PSI, "PSIONIST"),
]

CLASS_ANTI_LABELS = {
    "ANTI-CLERIC", "ANTI-MAGE", "ANTI-THIEF", "ANTI-WARRIOR", "ANTI-BARBARIAN",
    "ANTI-RANGER", "ANTI-PALADIN", "ANTI-PSIONIST", "ANTI-MONK", "ANTI-DRUID",
    "ANTI-SORCERER",
}

ALIGN_SLAYER_BITS = ["GOOD", "NEUTRAL", "EVIL"]

APPLY_IMMUNE = 26
APPLY_SUSC = 27
APPLY_M_IMMUNE = 28
APPLY_SPELL = 29
APPLY_WEAPON_SPELL = 30
APPLY_EAT_SPELL = 31
APPLY_ATTACKS = 42
APPLY_AFF2 = 44
APPLY_RACE_SLAYER = 47
APPLY_ALIGN_SLAYER = 48
APPLY_SPELLPOWER = 63
APPLY_HITNSP = 64
APPLY_SKIP = 65

_SPELLS: Optional[List[str]] = None
_RACE_NAMES: Optional[List[str]] = None


def _parse_c_string_array(path: Path, marker: str) -> List[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    start = text.find(marker)
    if start < 0:
        return []
    brace = text.find("{", start)
    end = text.find("};", brace)
    if brace < 0 or end < 0:
        return []
    block = text[brace + 1 : end]
    items: List[str] = []
    for match in re.finditer(r'"((?:\\.|[^"\\])*)"', block):
        items.append(match.group(1).encode("utf-8").decode("unicode_escape"))
    return items


def spells() -> List[str]:
    global _SPELLS
    if _SPELLS is None:
        _SPELLS = _parse_c_string_array(REPO_ROOT / "src" / "spell_parser.cpp", "const char* spells[]")
    return _SPELLS


def race_names() -> List[str]:
    global _RACE_NAMES
    if _RACE_NAMES is None:
        _RACE_NAMES = _parse_c_string_array(REPO_ROOT / "src" / "constants.cpp", "const char* RaceName[]")
    return _RACE_NAMES


def sprintbit(value: int, names: List[str]) -> List[str]:
    labels: List[str] = []
    for i, name in enumerate(names):
        if not name or name == "\n":
            continue
        if value & (1 << i):
            labels.append(name)
    return labels


def sprintbit2(value1: int, names1: List[str], value2: int, names2: List[str]) -> List[str]:
    return sprintbit(value1, names1) + sprintbit(value2, names2)


def _spell_name(spell_id: int) -> str:
    if spell_id < 1:
        return str(spell_id)
    idx = spell_id - 1
    sp = spells()
    if 0 <= idx < len(sp):
        return sp[idx]
    return str(spell_id)


def _apply_label(location: int) -> str:
    if 0 <= location < len(APPLY_TYPES):
        return APPLY_TYPES[location]
    return f"APPLY_{location}"


def format_affect(location: int, modifier: int) -> Optional[Dict[str, str]]:
    if location in (0, APPLY_SPELLPOWER, APPLY_HITNSP, APPLY_SKIP) or modifier == 0:
        return None

    label = _apply_label(location)
    if location in (APPLY_M_IMMUNE, APPLY_IMMUNE, APPLY_SUSC):
        bits = sprintbit(modifier, IMMUNITY_NAMES)
        value = " ".join(bits) if bits else str(modifier)
    elif location in (APPLY_WEAPON_SPELL, APPLY_EAT_SPELL):
        value = _spell_name(modifier)
    elif location == APPLY_ATTACKS:
        value = str(modifier / 10.0)
    elif location == APPLY_RACE_SLAYER:
        races = race_names()
        value = races[modifier] if 0 <= modifier < len(races) else str(modifier)
    elif location == APPLY_ALIGN_SLAYER:
        value = " ".join(sprintbit(modifier, ALIGN_SLAYER_BITS)) or str(modifier)
    else:
        value = str(modifier)

    return {
        "label": label,
        "value": value,
        "text": f"Ti puo' dare : {label} by {value}",
    }


def get_item_class_restrictions(extra_flags: int, only_class: bool) -> List[str]:
    """Come GetItemClassRestrictions() + regola wear.cpp (ANTI_MAGE → anche SORCERER se ONLY_CLASS)."""
    classes: List[str] = []
    for bit, name in CLASS_ANTI_BITS:
        if extra_flags & bit:
            classes.append(name)
    if only_class and (extra_flags & ITEM_ANTI_MAGE) and "SORCERER" not in classes:
        classes.append("SORCERER")
    return classes


def decode_class_and_extra_lines(extra_flags: int, extra_flags2: int) -> Dict[str, Any]:
    """Separa flag estetici/allineamento da restrizioni classe (ONLY-CLASS inverte ANTI-*)."""
    all_labels = sprintbit2(extra_flags, EXTRA_BITS, extra_flags2, EXTRA_BITS2)
    only_class = bool(extra_flags & ITEM_ONLY_CLASS) or "ONLY-CLASS" in all_labels

    other_flags: List[str] = []
    alignment: List[str] = []
    gender: List[str] = []

    for label in all_labels:
        if label in CLASS_ANTI_LABELS or label == "ONLY-CLASS":
            continue
        if label in ALIGNMENT_FLAGS:
            alignment.append(label.replace("ANTI-", ""))
        elif label in GENDER_FLAGS:
            gender.append("uomini" if label == "ANTI-MEN" else "donne")
        else:
            other_flags.append(label)

    class_names = get_item_class_restrictions(extra_flags, only_class)
    lines: List[str] = []

    if other_flags:
        lines.append(f"L'oggetto e': {' '.join(other_flags)}")

    if only_class:
        if class_names:
            lines.append(
                "ONLY-CLASS: usabile solo da " + ", ".join(class_names)
            )
        else:
            lines.append("ONLY-CLASS (nessun flag ANTI-classe impostato)")
    elif class_names:
        lines.append("Vietato alle classi: " + ", ".join(class_names))

    if alignment:
        lines.append("Vietato allineamento: " + ", ".join(alignment))
    if gender:
        lines.append("Vietato a: " + ", ".join(gender))

    return {
        "only_class": only_class,
        "allowed_classes": class_names if only_class else [],
        "forbidden_classes": class_names if not only_class else [],
        "other_flags": other_flags,
        "restriction_lines": lines,
        "all_extra_labels": all_labels,
    }


def decode_type_specific(type_flag: int, values: List[int]) -> List[Dict[str, str]]:
    v0, v1, v2, v3 = (values + [0, 0, 0, 0])[:4]
    lines: List[Dict[str, str]] = []

    if type_flag in (2, 10):  # SCROLL, POTION
        lines.append({"key": "spell_level", "label": "Livello incantesimo", "value": str(v0)})
        for i, slot in enumerate((v1, v2, v3), start=1):
            if slot >= 1:
                lines.append({"key": f"spell_{i}", "label": f"Incantesimo {i}", "value": _spell_name(slot)})

    elif type_flag in (3, 4):  # WAND, STAFF
        lines.append({"key": "charges_total", "label": "Cariche totali", "value": str(v1)})
        lines.append({"key": "charges_left", "label": "Cariche rimanenti", "value": str(v2)})
        lines.append({"key": "spell_level", "label": "Livello incantesimo", "value": str(v0)})
        if v3 >= 1:
            lines.append({"key": "spell", "label": "Incantesimo", "value": _spell_name(v3)})

    elif type_flag == 5:  # WEAPON
        lines.append({"key": "damage_dice", "label": "Dado di danno", "value": f"{v1}d{v2}"})
        wtype = WEAPON_TYPES[v3] if 0 <= v3 < len(WEAPON_TYPES) else str(v3)
        lines.append({"key": "damage_type", "label": "Tipo di danno", "value": wtype})

    elif type_flag == 9:  # ARMOR
        lines.append({"key": "ac_apply", "label": "AC-apply", "value": str(v0)})

    elif type_flag == 1:  # LIGHT
        if v2:
            lines.append({"key": "light_hours", "label": "Durata luce", "value": str(v2)})

    elif type_flag == 15:  # CONTAINER
        lines.append({"key": "capacity", "label": "Capacita'", "value": str(v0)})
        if v1:
            lines.append({"key": "container_flags", "label": "Flag contenitore", "value": str(v1)})

    elif type_flag == 19:  # FOOD
        lines.append({"key": "hours", "label": "Ore nutrimento", "value": str(v0)})
        if v3 >= 1:
            lines.append({"key": "spell", "label": "Effetto", "value": _spell_name(v3)})

    elif type_flag == 18:  # KEY
        lines.append({"key": "key_vnum", "label": "Chiave per", "value": str(v1)})

    return lines


def decode_object_characteristics(obj: Dict[str, Any]) -> Dict[str, Any]:
    type_flag = int(obj.get("type_flag") or 0)
    values = [
        int(obj.get("value0") or 0),
        int(obj.get("value1") or 0),
        int(obj.get("value2") or 0),
        int(obj.get("value3") or 0),
    ]
    extra_flags = int(obj.get("extra_flags") or 0)
    extra_flags2 = int(obj.get("extra_flags2") or 0)
    weight = int(obj.get("weight") or 0)
    cost = int(obj.get("cost") or 0)
    rent = int(obj.get("cost_per_day") or 0)

    extra_labels = sprintbit2(extra_flags, EXTRA_BITS, extra_flags2, EXTRA_BITS2)
    class_info = decode_class_and_extra_lines(extra_flags, extra_flags2)
    affects_raw = obj.get("affects")
    if isinstance(affects_raw, str):
        affects_raw = json.loads(affects_raw or "[]")
    affects: List[Dict[str, str]] = []
    for aff in affects_raw or []:
        entry = format_affect(int(aff.get("location", 0)), int(aff.get("modifier", 0)))
        if entry:
            affects.append(entry)

    type_specific = decode_type_specific(type_flag, values)
    item_type = ITEM_TYPES.get(type_flag, str(type_flag))
    rare = cost >= LIM_ITEM_COST_MIN

    lines: List[str] = []
    title = obj.get("short_desc") or obj.get("keywords") or f"#{obj.get('vnum')}"
    lines.append(f"Oggetto: '{title}', Tipo di Oggetto {item_type}")
    lines.extend(class_info["restriction_lines"])
    rent_part = f"{rent}"
    if rare:
        rent_part += " [RARO]"
    lines.append(f"Peso: {weight}, Valore: {cost}, Costo di rent: {rent_part}")

    for spec in type_specific:
        if spec["key"] == "ac_apply":
            lines.append(f"AC-apply di {spec['value']}.")
        elif spec["key"] == "damage_dice":
            dtype = next((s["value"] for s in type_specific if s["key"] == "damage_type"), "")
            lines.append(f"Dado di danno: '{spec['value']}'")
            if dtype:
                lines.append(f"Tipo di danno: '{dtype}'")
        elif spec["key"] == "damage_type":
            continue
        else:
            lines.append(f"{spec['label']}: {spec['value']}")

    if affects:
        lines.append("Caratteristiche:")
        for aff in affects:
            lines.append(f"    {aff['text']}")

    return {
        "title": title,
        "item_type": item_type,
        "extra_flags": extra_labels,
        "only_class": class_info["only_class"],
        "allowed_classes": class_info["allowed_classes"],
        "forbidden_classes": class_info["forbidden_classes"],
        "other_extra_flags": class_info["other_flags"],
        "weight": weight,
        "value": cost,
        "rent_cost": rent,
        "rare": rare,
        "type_specific": type_specific,
        "affects": affects,
        "summary_lines": lines,
    }
