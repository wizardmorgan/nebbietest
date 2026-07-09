"""Enum labels from shutils/enums.json for Myst asset decoding."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
ENUMS_PATH = REPO_ROOT / "shutils" / "enums.json"

_PREFIX_GROUPS = {
    "item_type": "ITEM_",
    "item_extra": "ITEM_",
    "item_wear": "ITEM_WEAR_",
    "item_wear2": "ITEM_WIELD",  # handled via full scan
    "act": "ACT_",
    "aff": "AFF_",
    "race": "RACE_",
    "sector": "SECT_",
    "apply": "APPLY_",
    "room": "",
}


def _load_enums() -> Dict[str, int]:
    data = json.loads(ENUMS_PATH.read_text(encoding="utf-8"))
    result: Dict[str, int] = {}
    for name, info in data.get("defines", {}).items():
        value = info.get("value")
        if isinstance(value, int):
            result[name] = value
    return result


ENUMS: Dict[str, int] = _load_enums()
VALUE_TO_NAME: Dict[int, List[str]] = {}
for name, value in ENUMS.items():
    VALUE_TO_NAME.setdefault(value, []).append(name)


def decode_flags(value: int, prefix: str | None = None) -> List[str]:
    if value == 0:
        return []
    labels: List[str] = []
    for bit_value, names in sorted(VALUE_TO_NAME.items(), reverse=True):
        if bit_value <= 0:
            continue
        if value & bit_value:
            for name in names:
                if prefix is None or name.startswith(prefix):
                    labels.append(name)
                    break
    if not labels and value:
        labels.append(str(value))
    return labels


ITEM_TYPE_NAMES = {
    0: "ITEM_NONE",
    1: "ITEM_LIGHT",
    2: "ITEM_SCROLL",
    3: "ITEM_WAND",
    4: "ITEM_STAFF",
    5: "ITEM_WEAPON",
    6: "ITEM_FIREWEAPON",
    7: "ITEM_MISSILE",
    8: "ITEM_TREASURE",
    9: "ITEM_ARMOR",
    10: "ITEM_POTION",
    11: "ITEM_WORN",
    12: "ITEM_OTHER",
    13: "ITEM_TRASH",
    14: "ITEM_TRAP",
    15: "ITEM_CONTAINER",
    16: "ITEM_NOTE",
    17: "ITEM_DRINKCON",
    18: "ITEM_KEY",
    19: "ITEM_FOOD",
    20: "ITEM_MONEY",
    21: "ITEM_PEN",
    22: "ITEM_BOAT",
    23: "ITEM_AUDIO",
    24: "ITEM_BOARD",
    25: "ITEM_TREE",
    26: "ITEM_ROCK",
    27: "ITEM_M_GEM",
    28: "ITEM_M_MINERAL",
    29: "ITEM_BAR",
    30: "ITEM_JEWEL",
}


def decode_item_type(value: int) -> str:
    return ITEM_TYPE_NAMES.get(value, str(value))


def decode_sector(value: int) -> str:
    for name in VALUE_TO_NAME.get(value, []):
        if name.startswith("SECT_"):
            return name
    return str(value)


def decode_race(value: int) -> str:
    for name in VALUE_TO_NAME.get(value, []):
        if name.startswith("RACE_"):
            return name
    return str(value)


def decode_apply(value: int) -> str:
    for name in VALUE_TO_NAME.get(value, []):
        if name.startswith("APPLY_"):
            return name
    return str(value)


def enum_options(prefix: str) -> List[Tuple[str, int]]:
    return sorted(
        [(name, value) for name, value in ENUMS.items() if name.startswith(prefix)],
        key=lambda item: item[1],
    )
