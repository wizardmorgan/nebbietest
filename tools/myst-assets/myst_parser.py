"""Parser for Myst MUD world files (myst.obj, myst.mob, myst.zon, myst.wld, myst.shp, myst.spe)."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional, TextIO


@dataclass
class ObjAffect:
    location: int
    modifier: int


@dataclass
class ExtraDescr:
    keyword: str
    description: str


@dataclass
class MystObject:
    vnum: int
    keywords: str
    short_desc: str
    long_desc: str
    action_desc: str
    type_flag: int
    extra_flags: int
    wear_flags: int
    value: List[int]
    weight: int
    cost: int
    cost_per_day: int
    affects: List[ObjAffect] = field(default_factory=list)
    extra_descriptions: List[ExtraDescr] = field(default_factory=list)
    extra_flags2: int = 0
    forbidden_wear_char: str = ""
    forbidden_wear_room: str = ""


@dataclass
class MystMob:
    vnum: int
    keywords: str
    short_desc: str
    long_desc: str
    description: str
    act: int
    affected_by: int
    alignment: int
    mobtype: str
    mult_att: float = 1.0
    level: int = 0
    hitroll: int = 0
    armor: int = 0
    max_hit: int = 0
    dam_dice: str = ""
    damroll: int = 0
    gold: int = 0
    exp: int = 0
    race: int = -1
    position: int = 0
    default_pos: int = 0
    sex: int = 0
    immune: int = 0
    m_immune: int = 0
    susc: int = 0
    sounds: str = ""
    distant_snds: str = ""


@dataclass
class RoomExit:
    direction: int
    description: str
    keyword: str
    exit_info: int
    key: int
    to_room: int
    open_cmd: int = -1


@dataclass
class MystRoom:
    vnum: int
    name: str
    description: str
    room_flags: int
    sector_type: int
    tele_time: int = 0
    tele_targ: int = 0
    tele_mask: int = 0
    tele_cnt: int = 0
    river_speed: int = 0
    river_dir: int = 0
    moblim: int = 0
    exits: List[RoomExit] = field(default_factory=list)
    extra_descriptions: List[ExtraDescr] = field(default_factory=list)
    bright_night: str = ""
    bright_day: str = ""


@dataclass
class ZoneReset:
    command: str
    if_flag: int
    arg1: int
    arg2: int
    arg3: int
    arg4: int
    raw_line: str = ""


@dataclass
class MystZone:
    zone_index: int
    zone_num: int
    name: str
    top: int
    lifespan: int
    reset_mode: int
    bottom: int = 0
    resets: List[ZoneReset] = field(default_factory=list)


@dataclass
class MystShop:
    vnum: int
    producing: List[int]
    profit_buy: float
    profit_sell: float
    trade_types: List[int]
    messages: Dict[str, str]
    temper1: int
    temper2: int
    keeper: int
    with_who: int
    in_room: int
    open1: int
    close1: int
    open2: int
    close2: int


@dataclass
class MystSpecial:
    kind: str
    vnum: int
    proc_name: str
    args: str
    raw_line: str


class MystReader:
    def __init__(self, fh: TextIO):
        self.fh = fh
        self._peek: Optional[str] = None
        self._pending_vnum: Optional[int] = None

    def push_vnum(self, token: str) -> None:
        if token.startswith("#"):
            num = token[1:]
            self._pending_vnum = int(num) if num else None
        elif token == "#":
            self._pending_vnum = -1  # sentinel: read number next
        else:
            raise ValueError(f"Not a vnum token: {token}")

    def pop_vnum(self) -> Optional[int]:
        if self._pending_vnum is None:
            return None
        if self._pending_vnum == -1:
            self._pending_vnum = None
            return self.fread_number()
        vnum = self._pending_vnum
        self._pending_vnum = None
        return vnum

    def _read_char(self) -> str:
        if self._peek is not None:
            ch = self._peek
            self._peek = None
            return ch
        ch = self.fh.read(1)
        if not ch:
            raise EOFError
        return ch

    def _unread(self, ch: str) -> None:
        self._peek = ch

    def skip_ws(self) -> None:
        while True:
            ch = self._read_char()
            if not ch.isspace():
                self._unread(ch)
                return

    def fread_string(self) -> str:
        self.skip_ws()
        parts: List[str] = []
        while True:
            ch = self._read_char()
            if ch == "~":
                break
            parts.append(ch)
        return "".join(parts)

    def fread_number(self) -> int:
        self.skip_ws()
        sign = False
        ch = self._read_char()
        if ch == "+":
            ch = self._read_char()
        elif ch == "-":
            sign = True
            ch = self._read_char()
        if not ch.isdigit():
            self._unread(ch)
            return 0
        number = 0
        while ch.isdigit():
            number = number * 10 + int(ch)
            ch = self._read_char()
        if sign:
            number = -number
        if ch == "|":
            number |= self.fread_number()
        elif ch and not ch.isspace():
            self._unread(ch)
        return number

    def fread_if_number(self) -> int:
        pos = self.fh.tell()
        try:
            return self.fread_number()
        except EOFError:
            self.fh.seek(pos)
            return 0

    def read_token(self) -> Optional[str]:
        try:
            self.skip_ws()
            ch = self._read_char()
        except EOFError:
            return None
        if ch in ("\n", "\r"):
            return self.read_token()
        token = [ch]
        while True:
            try:
                ch = self._read_char()
            except EOFError:
                break
            if ch.isspace():
                break
            token.append(ch)
        return "".join(token) if token else None

    def read_line(self) -> str:
        line = self.fh.readline()
        if not line:
            raise EOFError
        return line.rstrip("\r\n")

    def read_nonempty_line(self) -> str:
        while True:
            line = self.read_line().strip()
            if line:
                return line

    def read_int_line(self) -> int:
        return int(self.read_nonempty_line())

    def read_float_line(self) -> float:
        return float(self.read_nonempty_line())


def zone_for_vnum(vnum: int, zones: List[MystZone]) -> Optional[MystZone]:
    for zone in zones:
        if zone.bottom <= vnum <= zone.top:
            return zone
    return None


def read_vnum_token(reader: MystReader) -> int | None:
    pending = reader.pop_vnum()
    if pending is not None:
        return pending
    try:
        token = reader.read_token()
    except EOFError:
        return None
    if token is None:
        return None
    if token.startswith("#"):
        num = token[1:]
        return int(num) if num else reader.fread_number()
    if token == "#":
        return reader.fread_number()
    return None


def _finish_record(reader: MystReader, chk: Optional[str]) -> bool:
    """Return True if caller should stop processing current record."""
    if chk is None:
        return True
    if chk == "S":
        return True
    if chk.startswith("#"):
        reader.push_vnum(chk)
        return True
    return False


def parse_objects(path: Path) -> List[MystObject]:
    objects: List[MystObject] = []
    with path.open("r", encoding="latin-1", errors="replace") as fh:
        reader = MystReader(fh)
        while True:
            vnum = read_vnum_token(reader)
            if vnum is None:
                break
            try:
                obj = MystObject(
                    vnum=vnum,
                    keywords=reader.fread_string(),
                    short_desc=reader.fread_string(),
                    long_desc=reader.fread_string(),
                    action_desc=reader.fread_string(),
                    type_flag=reader.fread_number(),
                    extra_flags=reader.fread_number(),
                    wear_flags=reader.fread_number(),
                    value=[
                        reader.fread_number(),
                        reader.fread_number(),
                        reader.fread_number(),
                        reader.fread_number(),
                    ],
                    weight=reader.fread_number(),
                    cost=reader.fread_number(),
                    cost_per_day=reader.fread_number(),
                )
            except EOFError:
                break
            while True:
                chk = reader.read_token()
                if _finish_record(reader, chk):
                    break
                if chk == "E":
                    obj.extra_descriptions.append(
                        ExtraDescr(reader.fread_string(), reader.fread_string())
                    )
                    continue
                if chk == "A":
                    location = reader.fread_number()
                    modifier = reader.fread_number()
                    obj.affects.append(ObjAffect(location, modifier))
                    continue
                if chk == "F":
                    obj.extra_flags2 = reader.fread_number()
                    continue
                if chk == "P":
                    obj.forbidden_wear_char = reader.fread_string()
                    obj.forbidden_wear_room = reader.fread_string()
                    break
            objects.append(obj)
    return objects


def _parse_mob_stats(reader: MystReader, mob: MystMob, letter: str) -> None:
    if letter == "S":
        mob.level = reader.fread_number()
        mob.hitroll = 20 - reader.fread_number()
        armor_raw = reader.fread_number()
        mob.armor = 10 * armor_raw if abs(armor_raw) > 10 or armor_raw == 0 else 10 * armor_raw
        line = reader.read_line()
        m = re.search(r"(\d+)d(\d+)\+(-?\d+)", line)
        if m:
            mob.max_hit = int(m.group(3))  # simplified; real boot uses dice()
        m = re.search(r"(\d+)d(\d+)\+(-?\d+)\s*$", line)
        if m:
            mob.dam_dice = f"{m.group(1)}d{m.group(2)}+{m.group(3)}"
        else:
            parts = line.split()
            if len(parts) >= 2:
                mob.dam_dice = parts[-1]
        gold_or_minus = reader.fread_number()
        if gold_or_minus == -1:
            mob.gold = reader.fread_number()
            mob.exp = reader.fread_number()
            mob.race = reader.fread_number()
        else:
            mob.gold = gold_or_minus
            mob.exp = reader.fread_number()
        mob.position = reader.fread_number()
        mob.default_pos = reader.fread_number()
        sex_raw = reader.fread_number()
        if sex_raw < 3:
            mob.sex = sex_raw
        elif sex_raw < 6:
            mob.sex = sex_raw - 3
            mob.immune = reader.fread_number()
            mob.m_immune = reader.fread_number()
            mob.susc = reader.fread_number()
        return

    if letter in ("A", "N", "B", "L"):
        if letter in ("A", "B", "L"):
            mob.mult_att = float(reader.fread_number())
        reader.read_line()
        mob.level = reader.fread_number()
        mob.hitroll = 20 - reader.fread_number()
        mob.armor = 10 * reader.fread_number()
        mob.max_hit = reader.fread_number()
        line = reader.read_line()
        m = re.search(r"(\d+)d(\d+)\+(-?\d+)", line)
        if m:
            mob.dam_dice = f"{m.group(1)}d{m.group(2)}+{m.group(3)}"
            mob.damroll = int(m.group(3))
        gold_or_minus = reader.fread_number()
        if gold_or_minus == -1:
            mob.gold = reader.fread_number()
            mob.exp = abs(reader.fread_number())
            mob.race = reader.fread_number()
        else:
            mob.gold = gold_or_minus
            exp_raw = reader.fread_number()
            mob.exp = abs(exp_raw)
        mob.position = reader.fread_number()
        mob.default_pos = reader.fread_number()
        sex_raw = reader.fread_number()
        if sex_raw < 3:
            mob.sex = sex_raw
        elif sex_raw < 6:
            mob.sex = sex_raw - 3
            mob.immune = reader.fread_number()
            mob.m_immune = reader.fread_number()
            mob.susc = reader.fread_number()
        if letter == "L":
            mob.sounds = reader.fread_string()
            mob.distant_snds = reader.fread_string()


def parse_mobiles(path: Path) -> List[MystMob]:
    mobs: List[MystMob] = []
    with path.open("r", encoding="latin-1", errors="replace") as fh:
        reader = MystReader(fh)
        while True:
            vnum = read_vnum_token(reader)
            if vnum is None:
                break
            mob = MystMob(
                vnum=vnum,
                keywords=reader.fread_string(),
                short_desc=reader.fread_string(),
                long_desc=reader.fread_string(),
                description=reader.fread_string(),
                act=reader.fread_number(),
                affected_by=reader.fread_number(),
                alignment=reader.fread_number(),
                mobtype="?",
            )
            reader.skip_ws()
            letter = reader._read_char()
            mob.mobtype = letter
            _parse_mob_stats(reader, mob, letter)
            mobs.append(mob)
    return mobs


def parse_zones(path: Path) -> List[MystZone]:
    zones: List[MystZone] = []
    with path.open("r", encoding="latin-1", errors="replace") as fh:
        zone_index = 0
        while True:
            line = fh.readline()
            if not line:
                break
            line = line.strip()
            if not line.startswith("#"):
                continue
            zone_num = int(line[1:].strip())
            name = MystReader(fh).fread_string()
            if name == "$":
                break
            reader = MystReader(fh)
            top = reader.fread_number()
            lifespan = reader.fread_number()
            reset_mode = reader.fread_number()
            bottom = zones[-1].top + 1 if zones else 0
            zone = MystZone(
                zone_index=zone_index,
                zone_num=zone_num,
                name=name,
                top=top,
                lifespan=lifespan,
                reset_mode=reset_mode,
                bottom=bottom,
            )
            while True:
                raw = fh.readline()
                if not raw:
                    break
                raw = raw.rstrip("\r\n")
                stripped = raw.lstrip()
                if not stripped:
                    continue
                cmd = stripped[0]
                if cmd == "S":
                    break
                if cmd in "*;":
                    continue
                if cmd == "#":
                    fh.seek(fh.tell() - len(raw.encode("latin-1", errors="replace")))
                    break
                if cmd == "R":
                    continue
                if cmd not in "HFMCOGEPD":
                    continue
                nums = list(map(int, re.findall(r"-?\d+", stripped[1:])))
                while len(nums) < 5:
                    nums.append(0)
                zone.resets.append(
                    ZoneReset(
                        command=cmd,
                        if_flag=nums[0],
                        arg1=nums[1] if len(nums) > 1 else -1,
                        arg2=nums[2] if len(nums) > 2 else 0,
                        arg3=nums[3] if len(nums) > 3 else -1,
                        arg4=nums[4] if len(nums) > 4 else 0,
                        raw_line=raw,
                    )
                )
            zones.append(zone)
            zone_index += 1
    return zones


def parse_rooms(path: Path, zones: List[MystZone]) -> List[MystRoom]:
    rooms: List[MystRoom] = []
    with path.open("r", encoding="latin-1", errors="replace") as fh:
        reader = MystReader(fh)
        while True:
            vnum = read_vnum_token(reader)
            if vnum is None:
                break
            room = MystRoom(
                vnum=vnum,
                name=reader.fread_string(),
                description=reader.fread_string(),
                room_flags=0,
                sector_type=0,
            )
            if zones:
                reader.fread_number()  # legacy zone field in file
            room.room_flags = reader.fread_number()
            sector = reader.fread_number()
            room.sector_type = sector
            if sector == -1:
                room.tele_time = reader.fread_number()
                room.tele_targ = reader.fread_number()
                room.tele_mask = reader.fread_number()
                if room.tele_mask & 2:  # TELE_COUNT
                    room.tele_cnt = reader.fread_number()
                room.sector_type = reader.fread_number()
            if room.sector_type in (7, 9):  # SECT_WATER_NOSWIM, SECT_UNDERWATER
                room.river_speed = reader.fread_if_number()
                room.river_dir = reader.fread_if_number()
            if room.room_flags & 256:  # TUNNEL
                room.moblim = max(reader.fread_number(), 1)
            while True:
                chk = reader.read_token()
                if _finish_record(reader, chk):
                    break
                if chk.startswith("D") and chk[1:].isdigit():
                    direction = int(chk[1:])
                    room.exits.append(
                        RoomExit(
                            direction=direction,
                            description=reader.fread_string(),
                            keyword=reader.fread_string(),
                            exit_info=reader.fread_number(),
                            key=reader.fread_number(),
                            to_room=reader.fread_number(),
                            open_cmd=reader.fread_if_number(),
                        )
                    )
                elif chk == "E":
                    room.extra_descriptions.append(
                        ExtraDescr(reader.fread_string(), reader.fread_string())
                    )
                elif chk == "L":
                    room.bright_night = reader.fread_string()
                    room.bright_day = reader.fread_string()
                elif chk == "C":
                    continue
            rooms.append(room)
    return rooms


def parse_shops(path: Path) -> List[MystShop]:
    shops: List[MystShop] = []
    with path.open("r", encoding="latin-1", errors="replace") as fh:
        reader = MystReader(fh)
        while True:
            try:
                first = reader.fread_string()
            except EOFError:
                break
            if first == "$":
                break
            if not first.startswith("#"):
                continue
            vnum = int(first[1:])
            producing = [reader.read_int_line() for _ in range(5)]
            profit_buy = reader.read_float_line()
            profit_sell = reader.read_float_line()
            trade_types = [reader.read_int_line() for _ in range(5)]
            messages = {
                "no_such_item1": reader.fread_string(),
                "no_such_item2": reader.fread_string(),
                "do_not_buy": reader.fread_string(),
                "missing_cash1": reader.fread_string(),
                "missing_cash2": reader.fread_string(),
                "message_buy": reader.fread_string(),
                "message_sell": reader.fread_string(),
            }
            shops.append(
                MystShop(
                    vnum=vnum,
                    producing=producing,
                    profit_buy=profit_buy,
                    profit_sell=profit_sell,
                    trade_types=trade_types,
                    messages=messages,
                    temper1=reader.read_int_line(),
                    temper2=reader.read_int_line(),
                    keeper=reader.read_int_line(),
                    with_who=reader.read_int_line(),
                    in_room=reader.read_int_line(),
                    open1=reader.read_int_line(),
                    close1=reader.read_int_line(),
                    open2=reader.read_int_line(),
                    close2=reader.read_int_line(),
                )
            )
    return shops


def parse_specials(path: Path) -> List[MystSpecial]:
    specials: List[MystSpecial] = []
    with path.open("r", encoding="latin-1", errors="replace") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("*"):
                continue
            parts = line.split(None, 2)
            if len(parts) < 2:
                continue
            kind = parts[0]
            if kind not in ("M", "O", "R", "E", "P"):
                continue
            try:
                vnum = int(parts[1])
            except ValueError:
                continue
            rest = parts[2] if len(parts) > 2 else ""
            proc_name = rest.split()[0] if rest else ""
            specials.append(
                MystSpecial(
                    kind=kind,
                    vnum=vnum,
                    proc_name=proc_name,
                    args=rest,
                    raw_line=line,
                )
            )
    return specials


def load_world(lib_dir: Path) -> Dict[str, Any]:
    zones = parse_zones(lib_dir / "myst.zon")
    return {
        "zones": zones,
        "objects": parse_objects(lib_dir / "myst.obj"),
        "mobiles": parse_mobiles(lib_dir / "myst.mob"),
        "rooms": parse_rooms(lib_dir / "myst.wld", zones),
        "shops": parse_shops(lib_dir / "myst.shp"),
        "specials": parse_specials(lib_dir / "myst.spe"),
    }
