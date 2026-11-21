#!/usr/bin/env python3
"""Unit + HTTP smoke for ident-sync-server (no external deps)."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
import server  # noqa: E402


def check(name: str, cond: bool) -> None:
    if not cond:
        raise SystemExit("FAIL: " + name)
    print("OK  ", name)


def test_merge_logic() -> None:
    a = {"lastAt": 10, "objectName": "Anello", "byCharacter": {"A": {"at": 10}}}
    b = {"lastAt": 20, "objectName": "Anello", "byCharacter": {"B": {"at": 20}}}
    merged, status = server.merge_entry(a, b)
    check("newer remote wins", status == "updated" and merged["lastAt"] == 20)
    check("byCharacter union", "A" in merged["byCharacter"] and "B" in merged["byCharacter"])

    older = {"lastAt": 5, "objectName": "Anello", "byCharacter": {"C": {"at": 5}}}
    merged2, status2 = server.merge_entry(merged, older)
    check("older incoming unchanged body", status2 == "unchanged" and merged2["lastAt"] == 20)
    check("older still unions byCharacter", "C" in merged2["byCharacter"])

    # Config: additive only
    base = {"he": "he = heal"}
    merged_cfg, st_cfg = server.merge_config_entries(
        base, {"he": "he = OTHER", "ts": "ts = true sight"}
    )
    check("config insert new key", st_cfg["inserted"] == 1 and "ts" in merged_cfg)
    check("config never overwrite", merged_cfg["he"] == "he = heal" and st_cfg["unchanged"] == 1)


def http_json(url: str, method: str = "GET", body: dict | None = None, token: str | None = None):
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=5) as resp:
        return resp.status, json.loads(resp.read().decode("utf-8"))


def test_http() -> None:
    token = "test-token-ident-sync"
    with tempfile.TemporaryDirectory() as td:
        data = Path(td) / "ident-db.json"
        env = os.environ.copy()
        env["NEBBIE_IDENT_TOKEN"] = token
        env["NEBBIE_IDENT_DATA"] = str(data)
        env["NEBBIE_IDENT_HOST"] = "127.0.0.1"
        env["NEBBIE_IDENT_PORT"] = "18787"
        proc = subprocess.Popen(
            [sys.executable, str(ROOT / "server.py")],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
        try:
            base = "http://127.0.0.1:18787"
            for _ in range(40):
                try:
                    st, health = http_json(base + "/health")
                    if st == 200 and health.get("ok"):
                        break
                except Exception:
                    time.sleep(0.05)
            else:
                err = proc.stderr.read().decode("utf-8", "replace") if proc.stderr else ""
                raise SystemExit("server did not start:\n" + err)

            check("health ok", health["ok"] is True and health["entries"] == 0)

            try:
                http_json(base + "/v1/ident")
                raise SystemExit("FAIL: expected 401 without token")
            except urllib.error.HTTPError as e:
                check("get without token → 401", e.code == 401)

            st, page = http_json(base + "/v1/ident?page=1&page_size=5", token=token)
            check("empty page", st == 200 and page["total"] == 0 and page["entries"] == {})

            payload = {
                "entries": {
                    "anello prova": {
                        "key": "anello prova",
                        "objectName": "Anello Prova",
                        "objectType": "ARMOR",
                        "lastAt": 100,
                        "affects": ["STR by 1"],
                        "byCharacter": {"Mirari": {"at": 100}},
                    }
                }
            }
            st, merge = http_json(base + "/v1/ident/merge", method="POST", body=payload, token=token)
            check("merge insert", st == 200 and merge["inserted"] == 1 and merge["total"] == 1)

            st, page = http_json(base + "/v1/ident?page=1", token=token)
            check("page has entry", st == 200 and "anello prova" in page["entries"])

            # older push must not overwrite
            older = {
                "entries": {
                    "anello prova": {
                        "key": "anello prova",
                        "objectName": "Anello Prova OLD",
                        "objectType": "ARMOR",
                        "lastAt": 50,
                        "byCharacter": {"Sirio": {"at": 50}},
                    }
                }
            }
            st, merge2 = http_json(base + "/v1/ident/merge", method="POST", body=older, token=token)
            check("older merge unchanged body", merge2["unchanged"] == 1)
            st, page = http_json(base + "/v1/ident?page=1", token=token)
            ent = page["entries"]["anello prova"]
            check("name kept newer", ent["objectName"] == "Anello Prova")
            check("byCharacter union Sirio", "Sirio" in ent["byCharacter"] and "Mirari" in ent["byCharacter"])

            # --- config sync additive ---
            cfg_payload = {
                "files": {
                    "nebbie-spell-shortcuts.txt": {
                        "entries": {"he": "he = heal", "ts": "ts = true sight"}
                    }
                }
            }
            st, cfg_merge = http_json(
                base + "/v1/config/merge", method="POST", body=cfg_payload, token=token
            )
            check(
                "config merge insert",
                st == 200 and cfg_merge["inserted"] == 2 and cfg_merge["ok"] is True,
            )
            st, files = http_json(base + "/v1/config/files", token=token)
            check(
                "config files list",
                st == 200
                and len(files["files"]) == 1
                and files["files"][0]["file"] == "nebbie-spell-shortcuts.txt",
            )
            st, cfg_page = http_json(
                base + "/v1/config?file=nebbie-spell-shortcuts.txt&page=1", token=token
            )
            check("config page has he", st == 200 and "he" in cfg_page["entries"])
            # overwrite attempt must leave original
            overwrite = {
                "files": {
                    "nebbie-spell-shortcuts.txt": {
                        "entries": {"he": "he = OVERWRITE", "wo": "wo = word of recall"}
                    }
                }
            }
            st, cfg_merge2 = http_json(
                base + "/v1/config/merge", method="POST", body=overwrite, token=token
            )
            check("config additive insert wo", cfg_merge2["inserted"] == 1)
            st, cfg_page = http_json(
                base + "/v1/config?file=nebbie-spell-shortcuts.txt&page=1", token=token
            )
            check("config he not overwritten", cfg_page["entries"]["he"] == "he = heal")
            check("config wo present", cfg_page["entries"].get("wo") == "wo = word of recall")
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()


def main() -> int:
    test_merge_logic()
    test_http()
    print("ALL SERVER TESTS OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
