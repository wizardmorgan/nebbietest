"""Import Myst world files into a searchable SQLite database."""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path
from typing import Any, Dict, Iterable, List

from myst_enums import decode_flags, decode_item_type, decode_race, decode_sector
from myst_paths import resolve_lib_dir
from myst_parser import MystMob, MystObject, MystRoom, MystShop, MystSpecial, MystZone, load_world, zone_for_vnum

SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS zones (
    zone_index INTEGER PRIMARY KEY,
    zone_num INTEGER NOT NULL,
    name TEXT NOT NULL,
    bottom INTEGER NOT NULL,
    top INTEGER NOT NULL,
    lifespan INTEGER NOT NULL,
    reset_mode INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS objects (
    vnum INTEGER PRIMARY KEY,
    zone_index INTEGER,
    keywords TEXT,
    short_desc TEXT,
    long_desc TEXT,
    action_desc TEXT,
    type_flag INTEGER,
    type_name TEXT,
    extra_flags INTEGER,
    wear_flags INTEGER,
    extra_flags2 INTEGER,
    value0 INTEGER,
    value1 INTEGER,
    value2 INTEGER,
    value3 INTEGER,
    weight INTEGER,
    cost INTEGER,
    cost_per_day INTEGER,
    affects_json TEXT,
    extra_json TEXT,
    forbidden_wear_char TEXT,
    forbidden_wear_room TEXT,
    flags_text TEXT,
    search_text TEXT
);

CREATE TABLE IF NOT EXISTS mobiles (
    vnum INTEGER PRIMARY KEY,
    zone_index INTEGER,
    keywords TEXT,
    short_desc TEXT,
    long_desc TEXT,
    description TEXT,
    act INTEGER,
    affected_by INTEGER,
    alignment INTEGER,
    mobtype TEXT,
    mult_att REAL,
    level INTEGER,
    hitroll INTEGER,
    armor INTEGER,
    max_hit INTEGER,
    dam_dice TEXT,
    damroll INTEGER,
    gold INTEGER,
    exp INTEGER,
    race INTEGER,
    race_name TEXT,
    position INTEGER,
    default_pos INTEGER,
    sex INTEGER,
    immune INTEGER,
    m_immune INTEGER,
    susc INTEGER,
    sounds TEXT,
    distant_snds TEXT,
    act_text TEXT,
    aff_text TEXT,
    search_text TEXT
);

CREATE TABLE IF NOT EXISTS rooms (
    vnum INTEGER PRIMARY KEY,
    zone_index INTEGER,
    name TEXT,
    description TEXT,
    room_flags INTEGER,
    sector_type INTEGER,
    sector_name TEXT,
    tele_time INTEGER,
    tele_targ INTEGER,
    tele_mask INTEGER,
    tele_cnt INTEGER,
    river_speed INTEGER,
    river_dir INTEGER,
    moblim INTEGER,
    exits_json TEXT,
    extra_json TEXT,
    bright_night TEXT,
    bright_day TEXT,
    flags_text TEXT,
    search_text TEXT
);

CREATE TABLE IF NOT EXISTS zone_resets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    zone_index INTEGER NOT NULL,
    seq INTEGER NOT NULL,
    command TEXT NOT NULL,
    if_flag INTEGER,
    arg1 INTEGER,
    arg2 INTEGER,
    arg3 INTEGER,
    arg4 INTEGER,
    raw_line TEXT
);

CREATE TABLE IF NOT EXISTS shops (
    vnum INTEGER PRIMARY KEY,
    producing_json TEXT,
    profit_buy REAL,
    profit_sell REAL,
    trade_types_json TEXT,
    messages_json TEXT,
    temper1 INTEGER,
    temper2 INTEGER,
    keeper INTEGER,
    with_who INTEGER,
    in_room INTEGER,
    open1 INTEGER,
    close1 INTEGER,
    open2 INTEGER,
    close2 INTEGER,
    search_text TEXT
);

CREATE TABLE IF NOT EXISTS specials (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,
    vnum INTEGER NOT NULL,
    proc_name TEXT,
    args TEXT,
    raw_line TEXT
);

CREATE VIRTUAL TABLE IF NOT EXISTS objects_fts USING fts5(
    vnum UNINDEXED,
    keywords,
    short_desc,
    long_desc,
    search_text,
    content='objects',
    content_rowid='vnum'
);

CREATE VIRTUAL TABLE IF NOT EXISTS mobiles_fts USING fts5(
    vnum UNINDEXED,
    keywords,
    short_desc,
    long_desc,
    description,
    search_text,
    content='mobiles',
    content_rowid='vnum'
);

CREATE VIRTUAL TABLE IF NOT EXISTS rooms_fts USING fts5(
    vnum UNINDEXED,
    name,
    description,
    search_text,
    content='rooms',
    content_rowid='vnum'
);
"""


def _search_blob(*parts: str) -> str:
    return " ".join(p for p in parts if p)


def _zone_index(zones: List[MystZone], vnum: int) -> int | None:
    zone = zone_for_vnum(vnum, zones)
    return zone.zone_index if zone else None


def import_world(lib_dir: Path, db_path: Path) -> Dict[str, int]:
    world = load_world(lib_dir)
    zones: List[MystZone] = world["zones"]
    objects: List[MystObject] = world["objects"]
    mobiles: List[MystMob] = world["mobiles"]
    rooms: List[MystRoom] = world["rooms"]
    shops: List[MystShop] = world["shops"]
    specials: List[MystSpecial] = world["specials"]

    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    conn.executescript(SCHEMA)

    conn.executemany(
        "INSERT INTO zones VALUES (?,?,?,?,?,?,?)",
        [
            (z.zone_index, z.zone_num, z.name, z.bottom, z.top, z.lifespan, z.reset_mode)
            for z in zones
        ],
    )

    conn.executemany(
        """INSERT OR REPLACE INTO objects VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        [
            (
                o.vnum,
                _zone_index(zones, o.vnum),
                o.keywords,
                o.short_desc,
                o.long_desc,
                o.action_desc,
                o.type_flag,
                decode_item_type(o.type_flag),
                o.extra_flags,
                o.wear_flags,
                o.extra_flags2,
                o.value[0],
                o.value[1],
                o.value[2],
                o.value[3],
                o.weight,
                o.cost,
                o.cost_per_day,
                json.dumps([a.__dict__ for a in o.affects]),
                json.dumps([e.__dict__ for e in o.extra_descriptions]),
                o.forbidden_wear_char,
                o.forbidden_wear_room,
                ", ".join(decode_flags(o.extra_flags, "ITEM_")),
                _search_blob(o.keywords, o.short_desc, o.long_desc, o.action_desc),
            )
            for o in objects
        ],
    )

    conn.executemany(
        """INSERT OR REPLACE INTO mobiles (
            vnum, zone_index, keywords, short_desc, long_desc, description,
            act, affected_by, alignment, mobtype, mult_att, level, hitroll, armor,
            max_hit, dam_dice, damroll, gold, exp, race, race_name, position,
            default_pos, sex, immune, m_immune, susc, sounds, distant_snds,
            act_text, aff_text, search_text
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        [
            (
                m.vnum,
                _zone_index(zones, m.vnum),
                m.keywords,
                m.short_desc,
                m.long_desc,
                m.description,
                m.act,
                m.affected_by,
                m.alignment,
                m.mobtype,
                m.mult_att,
                m.level,
                m.hitroll,
                m.armor,
                m.max_hit,
                m.dam_dice,
                m.damroll,
                m.gold,
                m.exp,
                m.race,
                decode_race(m.race) if m.race >= 0 else "",
                m.position,
                m.default_pos,
                m.sex,
                m.immune,
                m.m_immune,
                m.susc,
                m.sounds,
                m.distant_snds,
                ", ".join(decode_flags(m.act, "ACT_")),
                ", ".join(decode_flags(m.affected_by, "AFF_")),
                _search_blob(m.keywords, m.short_desc, m.long_desc, m.description),
            )
            for m in mobiles
        ],
    )

    conn.executemany(
        """INSERT OR REPLACE INTO rooms VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        [
            (
                r.vnum,
                _zone_index(zones, r.vnum),
                r.name,
                r.description,
                r.room_flags,
                r.sector_type,
                decode_sector(r.sector_type),
                r.tele_time,
                r.tele_targ,
                r.tele_mask,
                r.tele_cnt,
                r.river_speed,
                r.river_dir,
                r.moblim,
                json.dumps([e.__dict__ for e in r.exits]),
                json.dumps([e.__dict__ for e in r.extra_descriptions]),
                r.bright_night,
                r.bright_day,
                ", ".join(decode_flags(r.room_flags)),
                _search_blob(r.name, r.description),
            )
            for r in rooms
        ],
    )

    reset_rows = []
    for zone in zones:
        for seq, reset in enumerate(zone.resets):
            reset_rows.append(
                (
                    zone.zone_index,
                    seq,
                    reset.command,
                    reset.if_flag,
                    reset.arg1,
                    reset.arg2,
                    reset.arg3,
                    reset.arg4,
                    reset.raw_line,
                )
            )
    conn.executemany(
        """INSERT INTO zone_resets (zone_index, seq, command, if_flag, arg1, arg2, arg3, arg4, raw_line)
           VALUES (?,?,?,?,?,?,?,?,?)""",
        reset_rows,
    )

    conn.executemany(
        """INSERT INTO shops VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        [
            (
                s.vnum,
                json.dumps(s.producing),
                s.profit_buy,
                s.profit_sell,
                json.dumps(s.trade_types),
                json.dumps(s.messages),
                s.temper1,
                s.temper2,
                s.keeper,
                s.with_who,
                s.in_room,
                s.open1,
                s.close1,
                s.open2,
                s.close2,
                _search_blob(str(s.vnum), str(s.keeper), str(s.in_room)),
            )
            for s in shops
        ],
    )

    conn.executemany(
        "INSERT INTO specials (kind, vnum, proc_name, args, raw_line) VALUES (?,?,?,?,?)",
        [(s.kind, s.vnum, s.proc_name, s.args, s.raw_line) for s in specials],
    )

    conn.executescript(
        """
        INSERT INTO objects_fts(objects_fts) VALUES('rebuild');
        INSERT INTO mobiles_fts(mobiles_fts) VALUES('rebuild');
        INSERT INTO rooms_fts(rooms_fts) VALUES('rebuild');
        """
    )

    conn.commit()
    counts = {
        "zones": len(zones),
        "objects": len(objects),
        "mobiles": len(mobiles),
        "rooms": len(rooms),
        "zone_resets": len(reset_rows),
        "shops": len(shops),
        "specials": len(specials),
    }
    conn.close()
    return counts


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Myst MUD assets into SQLite")
    parser.add_argument(
        "--lib-dir",
        type=Path,
        default=None,
        help="Directory con myst.obj/mob/zon/wld (default: auto-detect)",
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=Path(__file__).resolve().parent / "myst_assets.db",
    )
    args = parser.parse_args()
    lib_dir = resolve_lib_dir(args.lib_dir)
    counts = import_world(lib_dir, args.db)
    print(f"Asset source: {lib_dir}")
    print(f"Database written to {args.db}")
    for key, value in counts.items():
        print(f"  {key}: {value}")


if __name__ == "__main__":
    main()
