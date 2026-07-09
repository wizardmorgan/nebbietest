"""Build R-number indices like db.cpp generate_indices() / real_object()."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

from myst_parser import MystObject, parse_objects


@dataclass(frozen=True)
class ObjIndexEntry:
    rnum: int
    vnum: int


def _scan_main_obj_vnums(obj_file: Path) -> List[int]:
    """V-number in ordine di apparizione nel file principale (deduplicati)."""
    seen: set[int] = set()
    order: List[int] = []
    with obj_file.open("r", encoding="latin-1", errors="replace") as handle:
        for line in handle:
            if line.startswith("%%"):
                break
            if not line.startswith("#"):
                continue
            token = line[1:].strip()
            if not token.isdigit():
                continue
            vnum = int(token)
            if vnum >= 99999 or vnum in seen:
                continue
            seen.add(vnum)
            order.append(vnum)
    return order


def build_object_index(lib_dir: Path) -> List[ObjIndexEntry]:
    """Replica generate_indices(): myst.obj + directory objects/, ordinati per V-number."""
    obj_file = lib_dir / "myst.obj"
    obj_dir = lib_dir / "objects"
    discovered: Dict[int, None] = {}
    from_override: set[int] = set()

    for vnum in _scan_main_obj_vnums(obj_file):
        discovered[vnum] = None
        if (obj_dir / str(vnum)).is_file():
            from_override.add(vnum)

    if obj_dir.is_dir():
        for entry in sorted(obj_dir.iterdir(), key=lambda p: p.name):
            if entry.name.startswith(".") or not entry.name.isdigit():
                continue
            vnum = int(entry.name)
            if vnum <= 0 or vnum in discovered:
                continue
            if vnum in from_override:
                continue
            discovered[vnum] = None

    sorted_vnums = sorted(discovered.keys())
    return [ObjIndexEntry(rnum=rnum, vnum=vnum) for rnum, vnum in enumerate(sorted_vnums)]


def _attach_index_vnum(obj: MystObject, index_vnum: int) -> MystObject:
    """Allinea al boot MUD: V-number = indice (nome file in objects/), originale = # nel file."""
    header_vnum = obj.vnum
    obj.vnum = index_vnum
    if header_vnum != index_vnum:
        obj.original_vnum = header_vnum
    return obj


def load_indexed_objects(lib_dir: Path) -> List[tuple[ObjIndexEntry, MystObject]]:
    """Carica prototipi oggetto con R-number come in obj_index[]."""
    index = build_object_index(lib_dir)
    by_vnum: Dict[int, MystObject] = {}
    for obj in parse_objects(lib_dir / "myst.obj"):
        if obj.vnum < 99999 and obj.vnum not in by_vnum:
            by_vnum[obj.vnum] = obj

    obj_dir = lib_dir / "objects"
    if obj_dir.is_dir():
        for entry in obj_dir.iterdir():
            if not entry.name.isdigit():
                continue
            index_vnum = int(entry.name)
            parsed = parse_objects(entry)
            if parsed:
                by_vnum[index_vnum] = _attach_index_vnum(parsed[0], index_vnum)

    rows: List[tuple[ObjIndexEntry, MystObject]] = []
    for entry in index:
        obj = by_vnum.get(entry.vnum)
        if obj is None:
            continue
        if obj.vnum != entry.vnum:
            obj = _attach_index_vnum(obj, entry.vnum)
        rows.append((entry, obj))
    return rows


def vnum_to_rnum(lib_dir: Path) -> Dict[int, int]:
    return {entry.vnum: entry.rnum for entry in build_object_index(lib_dir)}
