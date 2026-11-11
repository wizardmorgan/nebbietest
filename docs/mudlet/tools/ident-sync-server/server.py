#!/usr/bin/env python3
"""NebbieDash identify-DB sync hub (VPS).

Minimal HTTPS-ready HTTP service (put nginx/caddy/stunnel in front).
Stdlib only. Auth: Authorization: Bearer <token>

Endpoints:
  GET  /health
  GET  /v1/ident?page=1&page_size=5
  POST /v1/ident/merge   body: {"entries": {key: entry, ...}}

Merge rule: keep entry with higher lastAt (int unix); on tie keep existing
server copy. byCharacter maps are unioned (per-char higher at wins).
"""
from __future__ import annotations

import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

TOKEN = os.environ.get("NEBBIE_IDENT_TOKEN", "").strip()
DATA_PATH = Path(os.environ.get("NEBBIE_IDENT_DATA", "./data/ident-db.json")).resolve()
HOST = os.environ.get("NEBBIE_IDENT_HOST", "127.0.0.1")
PORT = int(os.environ.get("NEBBIE_IDENT_PORT", "8787"))
PAGE_SIZE_DEFAULT = int(os.environ.get("NEBBIE_IDENT_PAGE_SIZE", "5"))
PAGE_SIZE_MAX = int(os.environ.get("NEBBIE_IDENT_PAGE_SIZE_MAX", "15"))
# Keep Mudlet getHTTP response under ~10k chars.
MAX_RESPONSE_CHARS = int(os.environ.get("NEBBIE_IDENT_MAX_RESPONSE_CHARS", "9000"))

_lock = threading.RLock()


def _empty_db() -> dict[str, Any]:
    return {"entries": {}, "updated_at": 0}


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
            self._send(
                200,
                {
                    "ok": True,
                    "service": "nebbie-ident-sync",
                    "entries": len(db["entries"]),
                    "updated_at": db.get("updated_at") or 0,
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
        self._send(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        if path != "/v1/ident/merge":
            self._send(404, {"ok": False, "error": "not_found"})
            return
        if not self._check_auth():
            return
        body = self._read_json()
        if not isinstance(body, dict) or not isinstance(body.get("entries"), dict):
            self._send(400, {"ok": False, "error": "invalid_body"})
            return
        with _lock:
            db = load_db()
            merged, stats = merge_entries(db["entries"], body["entries"])
            import time

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


def main() -> int:
    if not TOKEN:
        sys.stderr.write(
            "NEBBIE_IDENT_TOKEN is required (export a long random secret).\n"
        )
        return 2
    DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not DATA_PATH.exists():
        save_db(_empty_db())
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    sys.stderr.write(
        "nebbie-ident-sync listening on http://%s:%s  data=%s\n" % (HOST, PORT, DATA_PATH)
    )
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        sys.stderr.write("\nshutting down\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
