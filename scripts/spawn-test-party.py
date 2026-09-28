#!/usr/bin/env python3
"""
Prompt interattivo per creare un gruppo di test (3 PG livello 50) su Nebbie Arcane.

Genera il comando in-game `testparty` da incollare nel mud (immortale liv. 58+),
oppure lo invia via telnet se --send è specificato.

Uso:
  python3 scripts/spawn-test-party.py
  python3 scripts/spawn-test-party.py --send --host 127.0.0.1 --port 4000 --immortal MyImm
"""
from __future__ import annotations

import argparse
import re
import socket
import sys
import time
from typing import List, Optional

CLASS_HELP = """
Codici classe (concatena per multiclasse):
  M = Magico        C = Chierico      W = Guerriero
  T = Ladro         D = Druido        K = Monaco
  B = Barbaro       S = Stregone      P = Paladino
  R = Ranger        I = Psi

Esempi umano: W, MC, WCT, WCM, CT, P, I
"""

HUMAN_ALLOWED = {
    "M", "C", "W", "T", "D", "K", "B", "S", "P", "R", "I",
    "WC", "WT", "WM", "WCT", "WCM", "WMC", "CT", "MC", "TC",
    "WCT", "CTM", "WMC", "WCT", "WCM", "WMC",
    # mirror common combos from human_class_choice
    "W", "MC", "WCT", "WCM", "CTM",
}


def prompt(msg: str, default: Optional[str] = None) -> str:
    suffix = f" [{default}]" if default else ""
    while True:
        raw = input(f"{msg}{suffix}: ").strip()
        if raw:
            return raw
        if default is not None:
            return default
        print("  (obbligatorio)")


def normalize_class_code(code: str) -> str:
    c = re.sub(r"[^A-Za-z]", "", code).upper()
    if not c:
        raise ValueError("codice classe vuoto")
    if "M" in c and "S" in c:
        raise ValueError("Magico (M) e Stregone (S) sono mutuamente esclusivi")
    # ordine canonico per leggibilità
    order = "MCWTKBSPRI"
    return "".join(ch for ch in order if ch in c)


def validate_prefix(prefix: str) -> str:
    p = prefix.lower()
    if not re.fullmatch(r"[a-z][a-z0-9]{0,11}", p):
        raise ValueError("prefisso: 1-12 caratteri alfanumerici, inizia con lettera")
    for slot in (1, 2, 3):
        if len(p) + 1 > 15:
            raise ValueError("prefisso troppo lungo per prefisso1/2/3 (max 15 char PG)")
    return p


def collect_classes() -> List[str]:
    print(CLASS_HELP)
    classes: List[str] = []
    for i in range(1, 4):
        while True:
            try:
                code = normalize_class_code(prompt(f"PG {i} — classi"))
                classes.append(code)
                break
            except ValueError as e:
                print(f"  Errore: {e}")
    return classes


def build_command(prefix: str, classes: List[str]) -> str:
    return f"testparty create {prefix} {classes[0]} {classes[1]} {classes[2]}"


def telnet_exchange(host: str, port: int, lines: List[str], wait: float = 0.35) -> str:
    out = b""
    with socket.create_connection((host, port), timeout=10) as sock:
        sock.settimeout(0.5)
        time.sleep(0.5)
        try:
            out += sock.recv(8192)
        except socket.timeout:
            pass
        for line in lines:
            sock.sendall((line + "\n").encode("utf-8", errors="replace"))
            time.sleep(wait)
            try:
                while True:
                    chunk = sock.recv(8192)
                    if not chunk:
                        break
                    out += chunk
            except socket.timeout:
                pass
    return out.decode("utf-8", errors="replace")


def main() -> None:
    ap = argparse.ArgumentParser(description="Crea 3 PG di test livello 50 (testparty)")
    ap.add_argument("--prefix", help="prefisso nomi (default: interattivo)")
    ap.add_argument("--send", action="store_true", help="invia comandi via telnet")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=4000)
    ap.add_argument("--immortal", help="nome PG immortale per login telnet (--send)")
    ap.add_argument("--password", default="test", help="password immortale (--send)")
    ap.add_argument("--summon", action="store_true", help="dopo create, invia anche summon")
    args = ap.parse_args()

    print("=== Spawn Test Party — Nebbie Arcane ===\n")
    try:
        prefix = validate_prefix(args.prefix or prompt("Prefisso nomi (es. tparty"))
        classes = collect_classes()
    except (ValueError, KeyboardInterrupt) as e:
        if isinstance(e, KeyboardInterrupt):
            print("\nAnnullato.")
        else:
            print(f"Errore: {e}")
        raise SystemExit(1)

    create_cmd = build_command(prefix, classes)
    summon_cmd = f"testparty summon {prefix}"

    print("\n--- Comandi da eseguire in gioco (immortale) ---")
    print(create_cmd)
    print(summon_cmd)
    print("\nControllo da un solo PG:")
    print("  testparty cmd 1 <comando>   — azione sul PG 1")
    print("  testparty cmd 2 <comando>   — azione sul PG 2")
    print("  testparty cmd 3 <comando>   — azione sul PG 3")
    print("  testparty cmd all follow me — tutti seguono il controllore")
    print("  testparty dismiss", prefix, "  — fine sessione")
    print("\nPG creati:", f"{prefix}1, {prefix}2, {prefix}3 (password: test)")

    if not args.send:
        return

    if not args.immortal:
        print("--send richiede --immortal <nome>", file=sys.stderr)
        raise SystemExit(2)

    lines = [args.immortal, args.password, "1", create_cmd]
    if args.summon:
        lines.append(summon_cmd)
    print(f"\nInvio a {args.host}:{args.port} ...")
    transcript = telnet_exchange(args.host, args.port, lines)
    print(transcript[-4000:])


if __name__ == "__main__":
    main()
