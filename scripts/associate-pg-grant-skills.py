#!/usr/bin/env python3
"""Grant class skills/spells in character_skills for a migrated PG (dev/test)."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Set, Tuple

IMMORTALE = 52
SKILL_KNOWN = 1
DEFAULT_GOOD_LEVEL = 75  # how_good(): 71-80 = "buona"

CLASS_ALIASES: Dict[str, str] = {
    "mage": "mage", "magic": "mage", "mu": "mage", "wizard": "mage",
    "cleric": "cleric", "cl": "cleric", "priest": "cleric",
    "warrior": "warrior", "wa": "warrior", "war": "warrior",
    "thief": "thief", "th": "thief",
    "druid": "druid", "dr": "druid",
    "monk": "monk", "mo": "monk",
    "barbarian": "barbarian", "ba": "barbarian", "barb": "barbarian",
    "sorcerer": "sorcerer", "so": "sorcerer", "sor": "sorcerer",
    "paladin": "paladin", "pa": "paladin", "pal": "paladin",
    "ranger": "ranger", "ra": "ranger", "rng": "ranger",
    "psi": "psi", "psionic": "psi",
}

CLASS_FLAG: Dict[str, int] = {
    "mage": 4, "cleric": 2, "warrior": 128, "thief": 16, "druid": 64,
    "monk": 32, "barbarian": 256, "sorcerer": 8, "paladin": 512,
    "ranger": 1024, "psi": 2048,
}

CLASS_SKILL_IDS: Dict[str, List[int]] = {
    "warrior": [50, 51, 52, 208, 214],
    "thief": [45, 46, 47, 48, 49, 186, 176, 181, 175, 202, 203],
    "monk": [177, 199, 179, 176, 50, 46, 45, 49, 178, 183, 174, 173, 182],
    "barbarian": [
        183, 187, 186, 176, 173, 197, 198, 180, 174, 51, 170, 207, 209, 210,
        211, 208, 46, 214,
    ],
}

CLASS_INDEX_TO_NAME: Dict[int, str] = {
    0: "mage", 1: "cleric", 2: "warrior", 3: "thief", 4: "druid",
    5: "monk", 6: "barbarian", 7: "sorcerer", 8: "paladin", 9: "ranger",
    10: "psi",
}

SPELLLO_RE = re.compile(
    r"spello\(\s*(\d+)\s*,.*?/\*Mage\s*\*/\s*(\w+).*?/\*Cleric\s*\*/\s*(\w+).*?"
    r"/\*Druid\s*\*/\s*(\w+).*?/\*Sorcerer\s*\*/\s*(\w+).*?/\*Paladin\s*\*/\s*(\w+).*?"
    r"/\*Ranger\s*\*/\s*(\w+).*?/\*psIonic\s*\*/\s*(\w+)",
    re.DOTALL,
)


@dataclass(frozen=True)
class SpellReq:
    spell_id: int
    mage: int
    cleric: int
    druid: int
    sorcerer: int
    paladin: int
    ranger: int
    psi: int

    def min_for(self, class_name: str) -> int:
        return getattr(self, class_name)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def parse_spell_level(token: str) -> int:
    return int(token) if token.isdigit() else IMMORTALE


def load_spell_requirements(spell_list_path: Path) -> Dict[int, SpellReq]:
    text = spell_list_path.read_text(encoding="utf-8", errors="replace")
    out: Dict[int, SpellReq] = {}
    for match in SPELLLO_RE.finditer(text):
        levels = [parse_spell_level(match.group(i)) for i in range(2, 9)]
        out[int(match.group(1))] = SpellReq(int(match.group(1)), *levels)
    return out


def skill_flags(class_name: str) -> int:
    extra = CLASS_FLAG.get(class_name, 0)
    return SKILL_KNOWN if extra > 127 else (SKILL_KNOWN | extra)


def skills_for_class(
    class_name: str, level: int, spells: Dict[int, SpellReq]
) -> Set[Tuple[int, int]]:
    granted: Set[Tuple[int, int]] = set()
    flags = skill_flags(class_name)

    if class_name in CLASS_SKILL_IDS:
        for skill_id in CLASS_SKILL_IDS[class_name]:
            granted.add((skill_id, flags))
        return granted

    for spell in spells.values():
        req = spell.min_for(class_name)
        if req > 0 and req <= level:
            granted.add((spell.spell_id, flags))
    return granted


def mysql_query(host: str, port: str, user: str, password: str, database: str, sql: str) -> List[str]:
    cmd = ["mysql", "-h", host, "-P", port, "--protocol=TCP", f"-u{user}", f"-p{password}",
           "-N", "-B", "-e", sql, database]
    proc = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "mysql query failed")
    return [line for line in proc.stdout.splitlines() if line.strip()]


def mysql_exec(host: str, port: str, user: str, password: str, database: str, sql: str) -> None:
    cmd = ["mysql", "-h", host, "-P", port, "--protocol=TCP", f"-u{user}", f"-p{password}",
           "-e", sql, database]
    proc = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "mysql exec failed")


def table_exists(host: str, port: str, user: str, password: str, database: str, table: str) -> bool:
    sql = ("SELECT COUNT(*) FROM information_schema.tables "
           f"WHERE table_schema='{database}' AND table_name='{table}';")
    rows = mysql_query(host, port, user, password, database, sql)
    return bool(rows and rows[0] == "1")


def fetch_class_levels(host: str, port: str, user: str, password: str, database: str, toon_id: int) -> Dict[int, int]:
    sql = (f"SELECT class_index, level FROM character_classes "
           f"WHERE toon_id={toon_id} AND level > 0 ORDER BY class_index;")
    out: Dict[int, int] = {}
    for row in mysql_query(host, port, user, password, database, sql):
        idx_s, lvl_s = row.split("\t", 1)
        out[int(idx_s)] = int(lvl_s)
    return out


def fetch_toon_level(host: str, port: str, user: str, password: str, database: str, toon_id: int) -> int:
    rows = mysql_query(host, port, user, password, database,
                       f"SELECT level FROM toon WHERE id={toon_id} LIMIT 1;")
    if not rows:
        raise RuntimeError(f"toon id {toon_id} not found")
    return int(rows[0])


def normalize_classes(spec: str) -> List[str]:
    spec = spec.strip().lower()
    if not spec:
        raise ValueError("empty class list")
    if spec == "all":
        return ["all"]
    names: List[str] = []
    for part in re.split(r"[\s,;+]+", spec):
        part = part.strip()
        if not part:
            continue
        if part not in CLASS_ALIASES:
            raise ValueError(f"unknown class: {part}")
        canonical = CLASS_ALIASES[part]
        if canonical not in names:
            names.append(canonical)
    if not names:
        raise ValueError("no classes parsed")
    return names


def resolve_targets(class_spec: Sequence[str], class_levels: Dict[int, int], fallback_level: int) -> List[Tuple[str, int]]:
    if "all" in class_spec:
        if not class_levels:
            raise RuntimeError("no rows in character_classes; specify classes or boost levels first")
        return [(CLASS_INDEX_TO_NAME[idx], lvl) for idx, lvl in sorted(class_levels.items())
                if idx in CLASS_INDEX_TO_NAME]
    index_by_name = {v: k for k, v in CLASS_INDEX_TO_NAME.items()}
    targets: List[Tuple[str, int]] = []
    for name in class_spec:
        idx = index_by_name[name]
        level = class_levels.get(idx, fallback_level)
        if level <= 0:
            level = fallback_level
        targets.append((name, level))
    return targets


def build_upsert_sql(toon_id: int, skill_id: int, learned: int, flags: int) -> str:
    return (
        "INSERT INTO character_skills (toon_id, skill_id, learned, flags, special, nummem) VALUES "
        f"({toon_id}, {skill_id}, {learned}, {flags}, 0, 0) "
        f"ON DUPLICATE KEY UPDATE learned={learned}, flags={flags};"
    )


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Grant class skills/spells at buona proficiency.")
    parser.add_argument("--toon-id", type=int, required=True)
    parser.add_argument("--classes", required=True,
                        help="mage,cleric,... or all (from character_classes)")
    parser.add_argument("--good-level", type=int, default=DEFAULT_GOOD_LEVEL)
    parser.add_argument("--mysql-host", default="127.0.0.1")
    parser.add_argument("--mysql-port", default="3306")
    parser.add_argument("--mysql-user", default="root")
    parser.add_argument("--mysql-password", default="secret")
    parser.add_argument("--mysql-db", default="nebbie")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--spell-list", type=Path, default=repo_root() / "src" / "spell_list.cpp")
    args = parser.parse_args(argv)

    if args.good_level < 1 or args.good_level > 100:
        parser.error("--good-level must be 1..100")
    if not args.spell_list.is_file():
        parser.error(f"spell list not found: {args.spell_list}")
    if not table_exists(args.mysql_host, args.mysql_port, args.mysql_user,
                        args.mysql_password, args.mysql_db, "character_skills"):
        raise RuntimeError("table character_skills not found")

    class_levels = fetch_class_levels(args.mysql_host, args.mysql_port, args.mysql_user,
                                      args.mysql_password, args.mysql_db, args.toon_id)
    fallback_level = fetch_toon_level(args.mysql_host, args.mysql_port, args.mysql_user,
                                      args.mysql_password, args.mysql_db, args.toon_id)
    targets = resolve_targets(normalize_classes(args.classes), class_levels, fallback_level)
    spells = load_spell_requirements(args.spell_list)

    merged: Dict[int, int] = {}
    for class_name, level in targets:
        for skill_id, flags in skills_for_class(class_name, level, spells):
            merged[skill_id] = flags

    if not merged:
        print("No skills matched.", file=sys.stderr)
        return 1

    summary = ", ".join(f"{n}@{l}" for n, l in targets)
    print(f"==> Grant {len(merged)} skills toon_id={args.toon_id} learned={args.good_level} ({summary})")

    for skill_id in sorted(merged):
        sql = build_upsert_sql(args.toon_id, skill_id, args.good_level, merged[skill_id])
        if args.dry_run:
            print(f"[dry-run] {sql}")
        else:
            mysql_exec(args.mysql_host, args.mysql_port, args.mysql_user,
                       args.mysql_password, args.mysql_db, sql)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERRORE: {exc}", file=sys.stderr)
        raise SystemExit(1)
