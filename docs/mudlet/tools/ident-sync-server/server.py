#!/usr/bin/env python3
"""NebbieDash identify-DB + config-file sync hub (VPS).

Minimal HTTPS-ready HTTP service (put nginx/caddy/stunnel in front).
Stdlib only. Auth: Authorization: Bearer <token>

Endpoints:
  GET  /health
  GET  /v1/ident?page=1&page_size=5
  POST /v1/ident/merge   body: {"entries": {key: entry, ...}}
  GET  /v1/config/files
  GET  /v1/config?file=NAME&page=1&page_size=40
  POST /v1/config/merge  body: {"files": {name: {"entries": {key: value}}}}
  GET  /v1/ach?toon=NAME&page=1&page_size=30
  POST /v1/ach/merge     body: {"toons": {name: {"lista": {...}, "aggiornato": "..."}}}

Ident merge: higher lastAt wins; byCharacter unioned.
Config merge: **additive only** — insert missing keys, never overwrite values.
Ach merge: per-toon lista; higher prog wins (tie → higher t).
"""
from __future__ import annotations

import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

TOKEN = os.environ.get("NEBBIE_IDENT_TOKEN", "").strip()
DATA_PATH = Path(os.environ.get("NEBBIE_IDENT_DATA", "./data/ident-db.json")).resolve()
CONFIG_DATA_PATH = Path(
    os.environ.get(
        "NEBBIE_CONFIG_DATA",
        str(DATA_PATH.parent / "config-db.json"),
    )
).resolve()
ACH_DATA_PATH = Path(
    os.environ.get(
        "NEBBIE_ACH_DATA",
        str(DATA_PATH.parent / "ach-db.json"),
    )
).resolve()
HOST = os.environ.get("NEBBIE_IDENT_HOST", "127.0.0.1")
PORT = int(os.environ.get("NEBBIE_IDENT_PORT", "8787"))
PAGE_SIZE_DEFAULT = int(os.environ.get("NEBBIE_IDENT_PAGE_SIZE", "5"))
PAGE_SIZE_MAX = int(os.environ.get("NEBBIE_IDENT_PAGE_SIZE_MAX", "15"))
CONFIG_PAGE_SIZE_DEFAULT = int(os.environ.get("NEBBIE_CONFIG_PAGE_SIZE", "40"))
CONFIG_PAGE_SIZE_MAX = int(os.environ.get("NEBBIE_CONFIG_PAGE_SIZE_MAX", "80"))
ACH_PAGE_SIZE_DEFAULT = int(os.environ.get("NEBBIE_ACH_PAGE_SIZE", "30"))
ACH_PAGE_SIZE_MAX = int(os.environ.get("NEBBIE_ACH_PAGE_SIZE_MAX", "60"))
# Keep Mudlet getHTTP response under ~10k chars.
MAX_RESPONSE_CHARS = int(os.environ.get("NEBBIE_IDENT_MAX_RESPONSE_CHARS", "9000"))

_lock = threading.RLock()
_config_lock = threading.RLock()
_ach_lock = threading.RLock()


def _empty_db() -> dict[str, Any]:
    return {"entries": {}, "updated_at": 0}


def _empty_config_db() -> dict[str, Any]:
    return {"files": {}, "updated_at": 0}


def _empty_ach_db() -> dict[str, Any]:
    return {"toons": {}, "updated_at": 0}


def _ach_int(v: Any, default: int = 0) -> int:
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def normalize_ach_entry(entry: Any) -> dict[str, Any] | None:
    if not isinstance(entry, dict):
        return None
    nome = str(entry.get("nome") or "").strip()
    if nome == "":
        return None
    return {
        "num": _ach_int(entry.get("num"), 0),
        "nome": nome,
        "cat": str(entry.get("cat") or ""),
        "prog": _ach_int(entry.get("prog"), 0),
        "max": _ach_int(entry.get("max"), 0),
        "cont": str(entry.get("cont") or ""),
        "t": _ach_int(entry.get("t"), 0),
    }


def merge_ach_entry(
    existing: Any, incoming: Any
) -> tuple[dict[str, Any] | None, str]:
    a = normalize_ach_entry(existing)
    b = normalize_ach_entry(incoming)
    if a is None and b is None:
        return None, "skip"
    if a is None:
        return b, "inserted"
    if b is None:
        return a, "unchanged"
    if b["prog"] > a["prog"] or (b["prog"] == a["prog"] and b["t"] > a["t"]):
        out = dict(b)
        out["max"] = max(a["max"], b["max"])
        if out["cat"] == "" and a["cat"]:
            out["cat"] = a["cat"]
        if out["cont"] == "" and a["cont"]:
            out["cont"] = a["cont"]
        return out, "updated"
    out = dict(a)
    out["max"] = max(a["max"], b["max"])
    if out["cat"] == "" and b["cat"]:
        out["cat"] = b["cat"]
    if out["cont"] == "" and b["cont"]:
        out["cont"] = b["cont"]
    return out, "unchanged"


def merge_ach_toon(
    existing: Any, incoming: Any
) -> tuple[dict[str, Any], dict[str, int]]:
    cur = existing if isinstance(existing, dict) else {}
    inc = incoming if isinstance(incoming, dict) else {}
    cur_lista = cur.get("lista") if isinstance(cur.get("lista"), dict) else {}
    inc_lista = inc.get("lista") if isinstance(inc.get("lista"), dict) else {}
    out_lista: dict[str, Any] = dict(cur_lista)
    stats = {"inserted": 0, "updated": 0, "unchanged": 0}
    for key, entry in inc_lista.items():
        name = str(key or "").strip()
        if name == "":
            continue
        merged, status = merge_ach_entry(out_lista.get(name), entry)
        if merged is None:
            continue
        if status == "inserted":
            stats["inserted"] += 1
        elif status == "updated":
            stats["updated"] += 1
        else:
            stats["unchanged"] += 1
        out_lista[name] = merged
    aggiornato = str(inc.get("aggiornato") or cur.get("aggiornato") or "")
    # Prefer incoming aggiornato if any progress changed or incoming has stamp.
    if stats["inserted"] or stats["updated"]:
        if not aggiornato:
            aggiornato = str(inc.get("aggiornato") or cur.get("aggiornato") or "")
        elif inc.get("aggiornato"):
            aggiornato = str(inc.get("aggiornato"))
    updated_at = max(_ach_int(cur.get("updated_at")), _ach_int(inc.get("updated_at")), int(time.time()) if (stats["inserted"] or stats["updated"]) else 0)
    if not (stats["inserted"] or stats["updated"]):
        updated_at = max(_ach_int(cur.get("updated_at")), _ach_int(inc.get("updated_at")))
    return {
        "lista": out_lista,
        "aggiornato": aggiornato,
        "updated_at": updated_at,
    }, stats


def merge_ach_toons(
    server_toons: dict[str, Any], incoming_toons: dict[str, Any]
) -> tuple[dict[str, Any], dict[str, int]]:
    out = dict(server_toons)
    totals = {"inserted": 0, "updated": 0, "unchanged": 0, "toons_touched": 0}
    for name, blob in incoming_toons.items():
        toon = str(name or "").strip()
        if toon == "" or not isinstance(blob, dict):
            continue
        merged, stats = merge_ach_toon(out.get(toon), blob)
        if stats["inserted"] or stats["updated"]:
            totals["toons_touched"] += 1
        totals["inserted"] += stats["inserted"]
        totals["updated"] += stats["updated"]
        totals["unchanged"] += stats["unchanged"]
        out[toon] = merged
    return out, totals


def load_ach_db() -> dict[str, Any]:
    with _ach_lock:
        if not ACH_DATA_PATH.exists():
            return _empty_ach_db()
        try:
            raw = json.loads(ACH_DATA_PATH.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return _empty_ach_db()
        if not isinstance(raw, dict):
            return _empty_ach_db()
        toons_in = raw.get("toons")
        if not isinstance(toons_in, dict):
            toons_in = {}
        toons: dict[str, Any] = {}
        for name, blob in toons_in.items():
            if not isinstance(name, str) or name == "" or not isinstance(blob, dict):
                continue
            lista_in = blob.get("lista") if isinstance(blob.get("lista"), dict) else {}
            lista: dict[str, Any] = {}
            for k, e in lista_in.items():
                ne = normalize_ach_entry(e)
                if ne:
                    lista[str(k)] = ne
            toons[name] = {
                "lista": lista,
                "aggiornato": str(blob.get("aggiornato") or ""),
                "updated_at": _ach_int(blob.get("updated_at")),
            }
        return {"toons": toons, "updated_at": _ach_int(raw.get("updated_at"))}


def save_ach_db(db: dict[str, Any]) -> None:
    with _ach_lock:
        ACH_DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp = ACH_DATA_PATH.with_suffix(".tmp")
        tmp.write_text(json.dumps(db, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        tmp.replace(ACH_DATA_PATH)


def ach_page_payload(
    toon_blob: dict[str, Any], toon: str, page: int, page_size: int
) -> dict[str, Any]:
    lista = toon_blob.get("lista") if isinstance(toon_blob, dict) else {}
    if not isinstance(lista, dict):
        lista = {}
    keys = sorted(lista.keys())
    total = len(keys)
    pages = max(1, (total + page_size - 1) // page_size) if total else 1
    page = max(1, page)
    if page > pages:
        page = pages
    start = (page - 1) * page_size
    end = start + page_size
    slice_keys = keys[start:end]
    slice_lista = {k: lista[k] for k in slice_keys}
    while True:
        payload = {
            "ok": True,
            "toon": toon,
            "page": page,
            "page_size": page_size,
            "pages": pages,
            "total": total,
            "aggiornato": str(toon_blob.get("aggiornato") or "") if isinstance(toon_blob, dict) else "",
            "updated_at": _ach_int(toon_blob.get("updated_at")) if isinstance(toon_blob, dict) else 0,
            "lista": slice_lista,
        }
        encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        if len(encoded) <= MAX_RESPONSE_CHARS or len(slice_lista) <= 1:
            return payload
        last = next(reversed(slice_lista))
        del slice_lista[last]
        page_size = max(1, len(slice_lista))


def load_db() -> dict[str, Any]:
    with _lock:
        if not DATA_PATH.exists():
            return _empty_db()
        try:
            raw = json.loads(DATA_PATH.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return _empty_db()
        if not isinstance(raw, dict):
            return _empty_db()
        entries = raw.get("entries")
        if not isinstance(entries, dict):
            entries = {}
        return {"entries": entries, "updated_at": int(raw.get("updated_at") or 0)}


def save_db(db: dict[str, Any]) -> None:
    with _lock:
        DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp = DATA_PATH.with_suffix(".tmp")
        tmp.write_text(json.dumps(db, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        tmp.replace(DATA_PATH)


def load_config_db() -> dict[str, Any]:
    with _config_lock:
        if not CONFIG_DATA_PATH.exists():
            return _empty_config_db()
        try:
            raw = json.loads(CONFIG_DATA_PATH.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return _empty_config_db()
        if not isinstance(raw, dict):
            return _empty_config_db()
        files = raw.get("files")
        if not isinstance(files, dict):
            files = {}
        clean: dict[str, Any] = {}
        for name, blob in files.items():
            if not isinstance(name, str) or name == "":
                continue
            if not isinstance(blob, dict):
                continue
            entries = blob.get("entries")
            if not isinstance(entries, dict):
                entries = {}
            clean[name] = {
                "entries": {str(k): str(v) for k, v in entries.items() if k is not None},
                "updated_at": int(blob.get("updated_at") or 0),
            }
        return {"files": clean, "updated_at": int(raw.get("updated_at") or 0)}


def save_config_db(db: dict[str, Any]) -> None:
    with _config_lock:
        CONFIG_DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp = CONFIG_DATA_PATH.with_suffix(".tmp")
        tmp.write_text(json.dumps(db, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        tmp.replace(CONFIG_DATA_PATH)


def merge_config_entries(
    existing: dict[str, Any], incoming: dict[str, Any]
) -> tuple[dict[str, Any], dict[str, int]]:
    """Additive only: insert missing keys, never overwrite."""
    out = dict(existing)
    stats = {"inserted": 0, "unchanged": 0}
    for key, value in incoming.items():
        if not isinstance(key, str) or key == "":
            continue
        if key not in out:
            out[key] = value if isinstance(value, str) else str(value)
            stats["inserted"] += 1
        else:
            stats["unchanged"] += 1
    return out, stats


def merge_config_files(
    server_files: dict[str, Any], incoming_files: dict[str, Any]
) -> tuple[dict[str, Any], dict[str, int]]:
    out = dict(server_files)
    totals = {"inserted": 0, "unchanged": 0, "files_touched": 0}
    now = int(time.time())
    for name, blob in incoming_files.items():
        if not isinstance(name, str) or name == "":
            continue
        if not isinstance(blob, dict):
            continue
        entries = blob.get("entries")
        if not isinstance(entries, dict):
            continue
        cur = out.get(name)
        if not isinstance(cur, dict):
            cur = {"entries": {}, "updated_at": 0}
        merged, stats = merge_config_entries(cur.get("entries") or {}, entries)
        if stats["inserted"] > 0:
            totals["files_touched"] += 1
        totals["inserted"] += stats["inserted"]
        totals["unchanged"] += stats["unchanged"]
        out[name] = {"entries": merged, "updated_at": now if stats["inserted"] else int(cur.get("updated_at") or 0)}
    return out, totals


def config_page_payload(
    file_blob: dict[str, Any], file_name: str, page: int, page_size: int
) -> dict[str, Any]:
    entries = file_blob.get("entries") if isinstance(file_blob, dict) else {}
    if not isinstance(entries, dict):
        entries = {}
    keys = sorted(entries.keys())
    total = len(keys)
    pages = max(1, (total + page_size - 1) // page_size) if total else 1
    page = max(1, page)
    if page > pages:
        page = pages
    start = (page - 1) * page_size
    end = start + page_size
    slice_keys = keys[start:end]
    slice_entries = {k: entries[k] for k in slice_keys}
    while True:
        payload = {
            "ok": True,
            "file": file_name,
            "page": page,
            "page_size": page_size,
            "pages": pages,
            "total": total,
            "updated_at": int(file_blob.get("updated_at") or 0) if isinstance(file_blob, dict) else 0,
            "entries": slice_entries,
        }
        encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        if len(encoded) <= MAX_RESPONSE_CHARS or len(slice_entries) <= 1:
            return payload
        last = next(reversed(slice_entries))
        del slice_entries[last]
        page_size = max(1, len(slice_entries))


def entry_last_at(entry: Any) -> int:
    if not isinstance(entry, dict):
        return 0
    try:
        return int(entry.get("lastAt") or 0)
    except (TypeError, ValueError):
        return 0


def merge_by_character(a: Any, b: Any) -> dict[str, Any]:
    out: dict[str, Any] = {}
    if isinstance(a, dict):
        out.update(a)
    if isinstance(b, dict):
        for who, info in b.items():
            cur = out.get(who)
            if not isinstance(cur, dict):
                out[who] = info
                continue
            if not isinstance(info, dict):
                continue
            try:
                at_new = int(info.get("at") or 0)
            except (TypeError, ValueError):
                at_new = 0
            try:
                at_old = int(cur.get("at") or 0)
            except (TypeError, ValueError):
                at_old = 0
            if at_new >= at_old:
                out[who] = info
    return out


def merge_entry(existing: Any, incoming: Any) -> tuple[Any, str]:
    """Return (merged, status) where status is inserted|updated|unchanged."""
    if not isinstance(existing, dict):
        return incoming, "inserted"
    if not isinstance(incoming, dict):
        return existing, "unchanged"
    at_ex = entry_last_at(existing)
    at_in = entry_last_at(incoming)
    if at_in > at_ex:
        merged = dict(incoming)
        merged["byCharacter"] = merge_by_character(
            existing.get("byCharacter"), incoming.get("byCharacter")
        )
        return merged, "updated"
    if at_in < at_ex:
        merged = dict(existing)
        merged["byCharacter"] = merge_by_character(
            existing.get("byCharacter"), incoming.get("byCharacter")
        )
        # possession stays on existing (newer)
        return merged, "unchanged"
    # tie on lastAt: keep existing body, still union byCharacter
    merged = dict(existing)
    before = json.dumps(existing.get("byCharacter") or {}, sort_keys=True, separators=(",", ":"))
    merged["byCharacter"] = merge_by_character(
        existing.get("byCharacter"), incoming.get("byCharacter")
    )
    after = json.dumps(merged.get("byCharacter") or {}, sort_keys=True, separators=(",", ":"))
    return merged, "updated" if before != after else "unchanged"


def merge_entries(server_entries: dict[str, Any], incoming: dict[str, Any]) -> tuple[dict[str, Any], dict[str, int]]:
    out = dict(server_entries)
    stats = {"inserted": 0, "updated": 0, "unchanged": 0}
    for key, entry in incoming.items():
        if not isinstance(key, str) or key == "":
            continue
        if key not in out:
            if isinstance(entry, dict):
                out[key] = entry
                stats["inserted"] += 1
            continue
        merged, status = merge_entry(out[key], entry)
        out[key] = merged
        stats[status] = stats.get(status, 0) + 1
    return out, stats


def sorted_keys(entries: dict[str, Any]) -> list[str]:
    return sorted(entries.keys())


def page_payload(db: dict[str, Any], page: int, page_size: int) -> dict[str, Any]:
    keys = sorted_keys(db["entries"])
    total = len(keys)
    pages = max(1, (total + page_size - 1) // page_size) if total else 1
    page = max(1, page)
    if page > pages:
        page = pages
    start = (page - 1) * page_size
    end = start + page_size
    slice_keys = keys[start:end]
    entries = {k: db["entries"][k] for k in slice_keys}
    # Shrink page if JSON would exceed Mudlet getHTTP body limit.
    while True:
        payload = {
            "ok": True,
            "page": page,
            "page_size": page_size,
            "pages": pages,
            "total": total,
            "updated_at": db.get("updated_at") or 0,
            "entries": entries,
        }
        encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        if len(encoded) <= MAX_RESPONSE_CHARS or len(entries) <= 1:
            payload["_chars"] = len(encoded)
            return payload
        # drop last key
        last = next(reversed(entries))
        del entries[last]
        page_size = max(1, len(entries))


class Handler(BaseHTTPRequestHandler):
    server_version = "NebbieIdentSync/1.0"

    def log_message(self, fmt: str, *args: Any) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _read_json(self) -> Any:
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0:
            return None
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None

    def _send(self, code: int, obj: Any) -> None:
        body = json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _unauthorized(self) -> None:
        self._send(401, {"ok": False, "error": "unauthorized"})

    def _check_auth(self) -> bool:
        if not TOKEN:
            self._send(500, {"ok": False, "error": "server_misconfigured_no_token"})
            return False
        auth = (self.headers.get("Authorization") or "").strip()
        if auth.lower().startswith("bearer "):
            got = auth[7:].strip()
            if got == TOKEN:
                return True
        # Optional header alias
        got2 = (self.headers.get("X-Nebbie-Token") or "").strip()
        if got2 == TOKEN:
            return True
        self._unauthorized()
        return False

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        if path == "/health":
            db = load_db()
            cfg = load_config_db()
            ach = load_ach_db()
            cfg_entries = sum(
                len((blob.get("entries") or {}))
                for blob in (cfg.get("files") or {}).values()
                if isinstance(blob, dict)
            )
            ach_entries = sum(
                len((blob.get("lista") or {}))
                for blob in (ach.get("toons") or {}).values()
                if isinstance(blob, dict)
            )
            self._send(
                200,
                {
                    "ok": True,
                    "service": "nebbie-ident-sync",
                    "entries": len(db["entries"]),
                    "updated_at": db.get("updated_at") or 0,
                    "config_files": len(cfg.get("files") or {}),
                    "config_entries": cfg_entries,
                    "config_updated_at": cfg.get("updated_at") or 0,
                    "ach_toons": len(ach.get("toons") or {}),
                    "ach_entries": ach_entries,
                    "ach_updated_at": ach.get("updated_at") or 0,
                },
            )
            return
        if path == "/v1/ident":
            if not self._check_auth():
                return
            qs = parse_qs(parsed.query)
            try:
                page = int((qs.get("page") or ["1"])[0])
            except ValueError:
                page = 1
            try:
                page_size = int((qs.get("page_size") or [str(PAGE_SIZE_DEFAULT)])[0])
            except ValueError:
                page_size = PAGE_SIZE_DEFAULT
            page_size = max(1, min(page_size, PAGE_SIZE_MAX))
            db = load_db()
            payload = page_payload(db, page, page_size)
            # strip debug helper
            payload.pop("_chars", None)
            self._send(200, payload)
            return
        if path == "/v1/config/files":
            if not self._check_auth():
                return
            cfg = load_config_db()
            listing = []
            for name in sorted((cfg.get("files") or {}).keys()):
                blob = cfg["files"][name]
                entries = blob.get("entries") if isinstance(blob, dict) else {}
                listing.append(
                    {
                        "file": name,
                        "entries": len(entries) if isinstance(entries, dict) else 0,
                        "updated_at": int(blob.get("updated_at") or 0)
                        if isinstance(blob, dict)
                        else 0,
                    }
                )
            self._send(
                200,
                {
                    "ok": True,
                    "files": listing,
                    "updated_at": cfg.get("updated_at") or 0,
                },
            )
            return
        if path == "/v1/config":
            if not self._check_auth():
                return
            qs = parse_qs(parsed.query)
            file_name = ((qs.get("file") or [""])[0] or "").strip()
            if file_name == "":
                self._send(400, {"ok": False, "error": "missing_file"})
                return
            try:
                page = int((qs.get("page") or ["1"])[0])
            except ValueError:
                page = 1
            try:
                page_size = int(
                    (qs.get("page_size") or [str(CONFIG_PAGE_SIZE_DEFAULT)])[0]
                )
            except ValueError:
                page_size = CONFIG_PAGE_SIZE_DEFAULT
            page_size = max(1, min(page_size, CONFIG_PAGE_SIZE_MAX))
            cfg = load_config_db()
            blob = (cfg.get("files") or {}).get(file_name) or {
                "entries": {},
                "updated_at": 0,
            }
            self._send(200, config_page_payload(blob, file_name, page, page_size))
            return
        if path == "/v1/ach":
            if not self._check_auth():
                return
            qs = parse_qs(parsed.query)
            toon = ((qs.get("toon") or [""])[0] or "").strip()
            if toon == "":
                self._send(400, {"ok": False, "error": "missing_toon"})
                return
            try:
                page = int((qs.get("page") or ["1"])[0])
            except ValueError:
                page = 1
            try:
                page_size = int(
                    (qs.get("page_size") or [str(ACH_PAGE_SIZE_DEFAULT)])[0]
                )
            except ValueError:
                page_size = ACH_PAGE_SIZE_DEFAULT
            page_size = max(1, min(page_size, ACH_PAGE_SIZE_MAX))
            ach = load_ach_db()
            blob = (ach.get("toons") or {}).get(toon) or {
                "lista": {},
                "aggiornato": "",
                "updated_at": 0,
            }
            self._send(200, ach_page_payload(blob, toon, page, page_size))
            return
        self._send(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        if path == "/v1/ident/merge":
            if not self._check_auth():
                return
            body = self._read_json()
            if not isinstance(body, dict) or not isinstance(body.get("entries"), dict):
                self._send(400, {"ok": False, "error": "invalid_body"})
                return
            with _lock:
                db = load_db()
                merged, stats = merge_entries(db["entries"], body["entries"])
                db = {
                    "entries": merged,
                    "updated_at": int(time.time()),
                }
                save_db(db)
            self._send(
                200,
                {
                    "ok": True,
                    "inserted": stats["inserted"],
                    "updated": stats["updated"],
                    "unchanged": stats["unchanged"],
                    "total": len(merged),
                    "updated_at": db["updated_at"],
                },
            )
            return
        if path == "/v1/config/merge":
            if not self._check_auth():
                return
            body = self._read_json()
            if not isinstance(body, dict) or not isinstance(body.get("files"), dict):
                self._send(400, {"ok": False, "error": "invalid_body"})
                return
            with _config_lock:
                cfg = load_config_db()
                merged_files, stats = merge_config_files(cfg.get("files") or {}, body["files"])
                cfg = {
                    "files": merged_files,
                    "updated_at": int(time.time()),
                }
                save_config_db(cfg)
            self._send(
                200,
                {
                    "ok": True,
                    "inserted": stats["inserted"],
                    "unchanged": stats["unchanged"],
                    "files_touched": stats["files_touched"],
                    "files": len(merged_files),
                    "updated_at": cfg["updated_at"],
                },
            )
            return
        if path == "/v1/ach/merge":
            if not self._check_auth():
                return
            body = self._read_json()
            if not isinstance(body, dict) or not isinstance(body.get("toons"), dict):
                self._send(400, {"ok": False, "error": "invalid_body"})
                return
            with _ach_lock:
                ach = load_ach_db()
                merged_toons, stats = merge_ach_toons(ach.get("toons") or {}, body["toons"])
                ach = {
                    "toons": merged_toons,
                    "updated_at": int(time.time()),
                }
                save_ach_db(ach)
            self._send(
                200,
                {
                    "ok": True,
                    "inserted": stats["inserted"],
                    "updated": stats["updated"],
                    "unchanged": stats["unchanged"],
                    "toons_touched": stats["toons_touched"],
                    "toons": len(merged_toons),
                    "updated_at": ach["updated_at"],
                },
            )
            return
        self._send(404, {"ok": False, "error": "not_found"})


def main() -> int:
    if not TOKEN:
        sys.stderr.write(
            "NEBBIE_IDENT_TOKEN is required (export a long random secret).\n"
        )
        return 2
    DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not DATA_PATH.exists():
        save_db(_empty_db())
    CONFIG_DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not CONFIG_DATA_PATH.exists():
        save_config_db(_empty_config_db())
    ACH_DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not ACH_DATA_PATH.exists():
        save_ach_db(_empty_ach_db())
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    sys.stderr.write(
        "nebbie-ident-sync listening on http://%s:%s  ident=%s  config=%s  ach=%s\n"
        % (HOST, PORT, DATA_PATH, CONFIG_DATA_PATH, ACH_DATA_PATH)
    )
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        sys.stderr.write("\nshutting down\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
