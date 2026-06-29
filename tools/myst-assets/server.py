"""FastAPI server for Myst asset browser."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, PlainTextResponse, Response
from fastapi.staticfiles import StaticFiles

from myst_enums import enum_options
from object_decode import (
    EXTRA_BITS,
    EXTRA_BITS2,
    WEAR_BITS,
    decode_object_characteristics,
    extra_flag_masks_from_names,
    wear_flag_mask_from_names,
)
from myst_paths import resolve_lib_dir
from import_db import import_world

APP_DIR = Path(__file__).resolve().parent
DB_PATH = APP_DIR / "myst_assets.db"
LIB_DIR = resolve_lib_dir()

app = FastAPI(title="Myst Asset Browser", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.row_factory = sqlite3.Row
    return conn


def _table_query(
    table: str,
    fts_table: Optional[str],
    columns: List[str],
    *,
    q: Optional[str] = None,
    rnum_min: Optional[int] = None,
    rnum_max: Optional[int] = None,
    vnum_min: Optional[int] = None,
    vnum_max: Optional[int] = None,
    zone_index: Optional[int] = None,
    extra_where: Optional[str] = None,
    extra_params: Optional[List[Any]] = None,
    order_by: str = "vnum",
    fts_id_column: str = "vnum",
    limit: int = 100,
    offset: int = 0,
) -> Dict[str, Any]:
    where: List[str] = []
    params: List[Any] = list(extra_params or [])

    if rnum_min is not None:
        where.append("rnum >= ?")
        params.append(rnum_min)
    if rnum_max is not None:
        where.append("rnum <= ?")
        params.append(rnum_max)
    if vnum_min is not None:
        where.append("vnum >= ?")
        params.append(vnum_min)
    if vnum_max is not None:
        where.append("vnum <= ?")
        params.append(vnum_max)
    if zone_index is not None:
        where.append("zone_index = ?")
        params.append(zone_index)
    if extra_where:
        where.append(extra_where)

    if q and fts_table:
        where.append(
            f"{fts_id_column} IN (SELECT rowid FROM {fts_table} WHERE {fts_table} MATCH ?)"
        )
        params.append(q)

    where_sql = f"WHERE {' AND '.join(where)}" if where else ""
    count_sql = f"SELECT COUNT(*) FROM {table} {where_sql}"
    data_sql = f"SELECT {', '.join(columns)} FROM {table} {where_sql} ORDER BY {order_by} LIMIT ? OFFSET ?"

    with get_conn() as conn:
        total = conn.execute(count_sql, params).fetchone()[0]
        rows = conn.execute(data_sql, [*params, limit, offset]).fetchall()
    return {"total": total, "items": [dict(row) for row in rows]}


@app.on_event("startup")
def ensure_database() -> None:
    if not DB_PATH.exists():
        import_world(LIB_DIR, DB_PATH)


@app.get("/api/meta")
def meta() -> Dict[str, Any]:
    import_meta: Dict[str, Any] = {}
    meta_path = DB_PATH.with_name("import_meta.json")
    if meta_path.exists():
        import_meta = json.loads(meta_path.read_text(encoding="utf-8"))

    with get_conn() as conn:
        counts = {
            row[0]: row[1]
            for row in conn.execute(
                """
                SELECT 'zones', COUNT(*) FROM zones
                UNION ALL SELECT 'objects', COUNT(*) FROM objects
                UNION ALL SELECT 'mobiles', COUNT(*) FROM mobiles
                UNION ALL SELECT 'rooms', COUNT(*) FROM rooms
                UNION ALL SELECT 'zone_resets', COUNT(*) FROM zone_resets
                UNION ALL SELECT 'shops', COUNT(*) FROM shops
                UNION ALL SELECT 'specials', COUNT(*) FROM specials
                """
            )
        }
        zones = [
            dict(row)
            for row in conn.execute(
                "SELECT zone_index, zone_num, name, bottom, top FROM zones ORDER BY zone_index"
            )
        ]
    return {
        "counts": counts,
        "zones": zones,
        "lib_dir": import_meta.get("lib_dir", str(LIB_DIR)),
        "imported_at": import_meta.get("imported_at"),
        "source_counts": import_meta.get("counts"),
        "enums": {
            "item_types": enum_options("ITEM_")[:40],
            "acts": enum_options("ACT_"),
            "affs": enum_options("AFF_"),
            "sectors": enum_options("SECT_"),
            "races": enum_options("RACE_"),
            "extra_flags": EXTRA_BITS + EXTRA_BITS2,
            "wear_flags": WEAR_BITS,
        },
    }


def _parse_flag_names(raw: Optional[str]) -> List[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.replace(";", ",").split(",") if part.strip()]


@app.get("/api/objects")
def list_objects(
    q: Optional[str] = None,
    rnum_min: Optional[int] = None,
    rnum_max: Optional[int] = None,
    vnum_min: Optional[int] = None,
    vnum_max: Optional[int] = None,
    zone_index: Optional[int] = None,
    type_flag: Optional[int] = None,
    flags: Optional[str] = Query(
        None,
        description="Nomi extra flag separati da virgola, tutti richiesti (es. only-class, anti-ranger)",
    ),
    wear: Optional[str] = Query(
        None,
        description="Nomi wear flag separati da virgola, tutti richiesti (es. head, back, wield)",
    ),
    limit: int = Query(100, le=500),
    offset: int = 0,
) -> Dict[str, Any]:
    extra_where = []
    extra_params: List[Any] = []
    if type_flag is not None:
        extra_where.append("type_flag = ?")
        extra_params.append(type_flag)
    flag_names = _parse_flag_names(flags)
    if flag_names:
        mask1, mask2, unknown = extra_flag_masks_from_names(flag_names)
        if unknown:
            return {"total": 0, "items": [], "unknown_flags": unknown}
        if mask1:
            extra_where.append("(extra_flags & ?) = ?")
            extra_params.extend([mask1, mask1])
        if mask2:
            extra_where.append("(extra_flags2 & ?) = ?")
            extra_params.extend([mask2, mask2])
        if not mask1 and not mask2:
            return {"total": 0, "items": [], "unknown_flags": flag_names}
    wear_names = _parse_flag_names(wear)
    if wear_names:
        wear_mask, unknown_wear = wear_flag_mask_from_names(wear_names)
        if unknown_wear:
            return {"total": 0, "items": [], "unknown_wear_flags": unknown_wear}
        if not wear_mask:
            return {"total": 0, "items": [], "unknown_wear_flags": wear_names}
        extra_where.append("(wear_flags & ?) = ?")
        extra_params.extend([wear_mask, wear_mask])
    return _table_query(
        "objects",
        "objects_fts",
        [
            "rnum",
            "vnum",
            "original_vnum",
            "zone_index",
            "keywords",
            "short_desc",
            "type_name",
            "weight",
            "cost",
            "flags_text",
            "wear_text",
        ],
        q=q,
        rnum_min=rnum_min,
        rnum_max=rnum_max,
        vnum_min=vnum_min,
        vnum_max=vnum_max,
        zone_index=zone_index,
        extra_where=" AND ".join(extra_where) if extra_where else None,
        extra_params=extra_params,
        order_by="rnum",
        fts_id_column="rnum",
        limit=limit,
        offset=offset,
    )


@app.get("/api/objects/{rnum}")
def get_object(rnum: int) -> Dict[str, Any]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM objects WHERE rnum = ?", (rnum,)).fetchone()
    if not row:
        return {"error": "not found"}
    return _object_payload(dict(row))


@app.get("/api/objects/by-vnum/{vnum}")
def get_object_by_vnum(vnum: int) -> Dict[str, Any]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM objects WHERE vnum = ?", (vnum,)).fetchone()
    if not row:
        return {"error": "not found"}
    return _object_payload(dict(row))


def _object_payload(data: Dict[str, Any]) -> Dict[str, Any]:
    try:
        data["affects"] = json.loads(data.pop("affects_json") or "[]")
        data["extra_descriptions"] = json.loads(data.pop("extra_json") or "[]")
        data["characteristics"] = decode_object_characteristics(data)
        return data
    except Exception as exc:
        return {"error": "decode_failed", "message": str(exc), "rnum": data.get("rnum")}


@app.get("/api/mobiles")
def list_mobiles(
    q: Optional[str] = None,
    vnum_min: Optional[int] = None,
    vnum_max: Optional[int] = None,
    zone_index: Optional[int] = None,
    level_min: Optional[int] = None,
    level_max: Optional[int] = None,
    act_flag: Optional[int] = None,
    aff_flag: Optional[int] = None,
    race: Optional[int] = None,
    mobtype: Optional[str] = None,
    limit: int = Query(100, le=500),
    offset: int = 0,
) -> Dict[str, Any]:
    extra_where = []
    extra_params: List[Any] = []
    if level_min is not None:
        extra_where.append("level >= ?")
        extra_params.append(level_min)
    if level_max is not None:
        extra_where.append("level <= ?")
        extra_params.append(level_max)
    if act_flag is not None:
        extra_where.append("(act & ?) != 0")
        extra_params.append(act_flag)
    if aff_flag is not None:
        extra_where.append("(affected_by & ?) != 0")
        extra_params.append(aff_flag)
    if race is not None:
        extra_where.append("race = ?")
        extra_params.append(race)
    if mobtype:
        extra_where.append("mobtype = ?")
        extra_params.append(mobtype)
    return _table_query(
        "mobiles",
        "mobiles_fts",
        [
            "vnum",
            "zone_index",
            "keywords",
            "short_desc",
            "level",
            "race_name",
            "mobtype",
            "alignment",
            "dam_dice",
            "exp",
            "act_text",
            "aff_text",
        ],
        q=q,
        vnum_min=vnum_min,
        vnum_max=vnum_max,
        zone_index=zone_index,
        extra_where=" AND ".join(extra_where) if extra_where else None,
        extra_params=extra_params,
        limit=limit,
        offset=offset,
    )


@app.get("/api/mobiles/{vnum}")
def get_mobile(vnum: int) -> Dict[str, Any]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM mobiles WHERE vnum = ?", (vnum,)).fetchone()
    return dict(row) if row else {"error": "not found"}


@app.get("/api/rooms")
def list_rooms(
    q: Optional[str] = None,
    vnum_min: Optional[int] = None,
    vnum_max: Optional[int] = None,
    zone_index: Optional[int] = None,
    sector_type: Optional[int] = None,
    room_flag: Optional[int] = None,
    limit: int = Query(100, le=500),
    offset: int = 0,
) -> Dict[str, Any]:
    extra_where = []
    extra_params: List[Any] = []
    if sector_type is not None:
        extra_where.append("sector_type = ?")
        extra_params.append(sector_type)
    if room_flag is not None:
        extra_where.append("(room_flags & ?) != 0")
        extra_params.append(room_flag)
    return _table_query(
        "rooms",
        "rooms_fts",
        [
            "vnum",
            "zone_index",
            "name",
            "sector_name",
            "room_flags",
            "flags_text",
            "moblim",
        ],
        q=q,
        vnum_min=vnum_min,
        vnum_max=vnum_max,
        zone_index=zone_index,
        extra_where=" AND ".join(extra_where) if extra_where else None,
        extra_params=extra_params,
        limit=limit,
        offset=offset,
    )


@app.get("/api/rooms/{vnum}")
def get_room(vnum: int) -> Dict[str, Any]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM rooms WHERE vnum = ?", (vnum,)).fetchone()
    if not row:
        return {"error": "not found"}
    data = dict(row)
    data["exits"] = json.loads(data.pop("exits_json") or "[]")
    data["extra_descriptions"] = json.loads(data.pop("extra_json") or "[]")
    return data


@app.get("/api/zones")
def list_zones(
    q: Optional[str] = None,
    zone_num: Optional[int] = None,
    limit: int = Query(200, le=500),
    offset: int = 0,
) -> Dict[str, Any]:
    where = []
    params: List[Any] = []
    if q:
        where.append("name LIKE ?")
        params.append(f"%{q}%")
    if zone_num is not None:
        where.append("zone_num = ?")
        params.append(zone_num)
    where_sql = f"WHERE {' AND '.join(where)}" if where else ""
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) FROM zones {where_sql}", params).fetchone()[0]
        rows = conn.execute(
            f"SELECT * FROM zones {where_sql} ORDER BY zone_index LIMIT ? OFFSET ?",
            [*params, limit, offset],
        ).fetchall()
    return {"total": total, "items": [dict(r) for r in rows]}


@app.get("/api/zones/{zone_index}/resets")
def zone_resets(
    zone_index: int,
    command: Optional[str] = None,
    arg_vnum: Optional[int] = None,
    limit: int = Query(200, le=1000),
    offset: int = 0,
) -> Dict[str, Any]:
    where = ["zone_index = ?"]
    params: List[Any] = [zone_index]
    if command:
        where.append("command = ?")
        params.append(command.upper())
    if arg_vnum is not None:
        where.append("(arg1 = ? OR arg3 = ?)")
        params.extend([arg_vnum, arg_vnum])
    where_sql = " AND ".join(where)
    with get_conn() as conn:
        total = conn.execute(
            f"SELECT COUNT(*) FROM zone_resets WHERE {where_sql}", params
        ).fetchone()[0]
        rows = conn.execute(
            f"""SELECT id, zone_index, seq, command, if_flag, arg1, arg2, arg3, arg4, raw_line
                FROM zone_resets WHERE {where_sql}
                ORDER BY seq LIMIT ? OFFSET ?""",
            [*params, limit, offset],
        ).fetchall()
    return {"total": total, "items": [dict(r) for r in rows]}


@app.get("/api/resets")
def search_resets(
    command: Optional[str] = None,
    arg_vnum: Optional[int] = None,
    zone_index: Optional[int] = None,
    q: Optional[str] = None,
    limit: int = Query(100, le=500),
    offset: int = 0,
) -> Dict[str, Any]:
    where = []
    params: List[Any] = []
    if command:
        where.append("command = ?")
        params.append(command.upper())
    if arg_vnum is not None:
        where.append("(arg1 = ? OR arg3 = ?)")
        params.extend([arg_vnum, arg_vnum])
    if zone_index is not None:
        where.append("zone_index = ?")
        params.append(zone_index)
    if q:
        where.append("raw_line LIKE ?")
        params.append(f"%{q}%")
    where_sql = f"WHERE {' AND '.join(where)}" if where else ""
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) FROM zone_resets {where_sql}", params).fetchone()[0]
        rows = conn.execute(
            f"""SELECT zr.*, z.name AS zone_name, z.zone_num
                FROM zone_resets zr
                JOIN zones z ON z.zone_index = zr.zone_index
                {where_sql}
                ORDER BY zr.zone_index, zr.seq
                LIMIT ? OFFSET ?""",
            [*params, limit, offset],
        ).fetchall()
    return {"total": total, "items": [dict(r) for r in rows]}


@app.get("/api/shops")
def list_shops(
    q: Optional[str] = None,
    keeper: Optional[int] = None,
    in_room: Optional[int] = None,
    limit: int = Query(100, le=500),
    offset: int = 0,
) -> Dict[str, Any]:
    where = []
    params: List[Any] = []
    if q:
        where.append("search_text LIKE ?")
        params.append(f"%{q}%")
    if keeper is not None:
        where.append("keeper = ?")
        params.append(keeper)
    if in_room is not None:
        where.append("in_room = ?")
        params.append(in_room)
    where_sql = f"WHERE {' AND '.join(where)}" if where else ""
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) FROM shops {where_sql}", params).fetchone()[0]
        rows = conn.execute(
            f"SELECT * FROM shops {where_sql} ORDER BY vnum LIMIT ? OFFSET ?",
            [*params, limit, offset],
        ).fetchall()
    items = []
    for row in rows:
        data = dict(row)
        data["producing"] = json.loads(data.pop("producing_json") or "[]")
        data["trade_types"] = json.loads(data.pop("trade_types_json") or "[]")
        data["messages"] = json.loads(data.pop("messages_json") or "{}")
        items.append(data)
    return {"total": total, "items": items}


@app.get("/api/specials")
def list_specials(
    q: Optional[str] = None,
    kind: Optional[str] = None,
    vnum: Optional[int] = None,
    proc_name: Optional[str] = None,
    limit: int = Query(100, le=500),
    offset: int = 0,
) -> Dict[str, Any]:
    where = []
    params: List[Any] = []
    if q:
        where.append("(proc_name LIKE ? OR args LIKE ? OR raw_line LIKE ?)")
        params.extend([f"%{q}%", f"%{q}%", f"%{q}%"])
    if kind:
        where.append("kind = ?")
        params.append(kind.upper())
    if vnum is not None:
        where.append("vnum = ?")
        params.append(vnum)
    if proc_name:
        where.append("proc_name LIKE ?")
        params.append(f"%{proc_name}%")
    where_sql = f"WHERE {' AND '.join(where)}" if where else ""
    with get_conn() as conn:
        total = conn.execute(f"SELECT COUNT(*) FROM specials {where_sql}", params).fetchone()[0]
        rows = conn.execute(
            f"SELECT * FROM specials {where_sql} ORDER BY kind, vnum LIMIT ? OFFSET ?",
            [*params, limit, offset],
        ).fetchall()
    return {"total": total, "items": [dict(r) for r in rows]}


@app.post("/api/reimport")
def reimport() -> Dict[str, Any]:
    lib_dir = resolve_lib_dir()
    counts = import_world(lib_dir, DB_PATH)
    return {"status": "ok", "counts": counts, "lib_dir": str(lib_dir)}


@app.get("/health")
def health() -> PlainTextResponse:
    return PlainTextResponse("ok")


@app.get("/favicon.ico", include_in_schema=False)
def favicon() -> Response:
    return Response(status_code=204)


@app.get("/")
def index() -> FileResponse:
    return FileResponse(
        APP_DIR / "static" / "index.html",
        media_type="text/html; charset=utf-8",
    )


app.mount("/static", StaticFiles(directory=APP_DIR / "static"), name="static")
