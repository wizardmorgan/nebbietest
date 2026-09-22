#!/usr/bin/env python3
"""Verifica offline i log prodotti da `nbatch` (Nebbie Dashboard).

Confronta ogni sezione `--- riga N ---` del log con:
  - la riga CSV corrispondente
  - i comandi attesi (da nebbie-batch-commands.txt)
  - assenza di errori MUD noti
  - messaggio di successo osave (se presente nei comandi)

Uso tipico (dopo aver copiato log e CSV dal profilo Mudlet):

    python3 docs/mudlet/tests/verify_batch_log.py \\
      --csv /path/to/nebbie-batch-items.csv \\
      --commands /path/to/nebbie-batch-commands.txt \\
      --log /path/to/GreenBlade-2026-09-21.txt

Opzionale — verifica che i file oggetto esistano sul server (mudroot):

    python3 docs/mudlet/tests/verify_batch_log.py ... \\
      --objects-dir /path/to/mudroot/lib/objects

Exit code 0 = tutto OK, 1 = almeno un problema.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

BATCH_ERROR_PATTERNS = [
    "There is no such object.",
    "Hum, non ho idea di dove sia!",
    "Il v-number non e' valido.",
    "Il secondo valore non e' corretto.",
    "Mi dispiace ma non hai accesso a quella zona.",
    "Sorry, private items.",
    "When monkeys fly out of Ripper",
    "Questo oggetto non e' qui!",
    "Quale oggetto vuoi modificare?",
]

ROW_HEADER_RE = re.compile(r"^--- riga (\d+) — (.+) ---$")
BATCH_HEADER_RE = re.compile(r"^========== batch ")
BATCH_END_RE = re.compile(r"^--- batch terminato")
OSAVE_SUCCESS_RE = re.compile(
    r"Ho salvato .+ con il vnum (\d+) \(originale (\d+)\)"
)


@dataclass
class BatchRow:
    nome_toon: str
    key_raw: str
    key_norm: str
    vnum_attuale: str
    vnum_originale: str
    raw_line: str


@dataclass
class LogSection:
    row_idx: int
    time: str
    csv_line: str
    lines: list[str]


def normalize_batch_key(raw: str) -> str:
    key = raw.lower()
    key = re.sub(r"\s+", "-", key)
    key = re.sub(r"-+", "-", key)
    return key


def parse_csv_line(line: str) -> list[str]:
    fields: list[str] = []
    field: list[str] = []
    in_quotes = False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == '"':
            if in_quotes and i + 1 < len(line) and line[i + 1] == '"':
                field.append('"')
                i += 1
            else:
                in_quotes = not in_quotes
        elif ch == "," and not in_quotes:
            fields.append("".join(field).strip())
            field = []
        else:
            field.append(ch)
        i += 1
    fields.append("".join(field).strip())
    return fields


def load_csv(path: Path, toon_filter: str | None) -> list[BatchRow]:
    rows: list[BatchRow] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    header_done = False
    want = toon_filter.lower() if toon_filter else None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if not header_done:
            header_done = True
            continue
        fields = parse_csv_line(line)
        if len(fields) < 4:
            continue
        row = BatchRow(
            nome_toon=fields[0],
            key_raw=fields[1],
            key_norm=normalize_batch_key(fields[1]),
            vnum_attuale=fields[2],
            vnum_originale=fields[3],
            raw_line=line,
        )
        if want and row.nome_toon.lower() != want:
            continue
        rows.append(row)
    return rows


def load_commands(path: Path) -> list[str]:
    cmds: list[str] = []
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        cmds.append(line)
    return cmds


def substitute_vars(template: str, row: BatchRow) -> str:
    return (
        template.replace("$1", row.nome_toon)
        .replace("$2", row.key_norm)
        .replace("$3", row.vnum_attuale)
        .replace("$4", row.vnum_originale)
    )


def is_enter_command(template: str) -> bool:
    return bool(re.match(r"^\s*\[enter\]\s*$", template or ""))


def commands_with_nchar_prefix(commands: list[str]) -> list[str]:
    if not commands:
        return ["nchar Sirio"]
    first = commands[0].strip()
    if re.match(r"^nchar\s+sirio\s*$", first, re.IGNORECASE):
        return commands
    return ["nchar Sirio", *commands]


def prepare_command_log_label(template: str, row: BatchRow) -> str:
    if is_enter_command(template):
        return "[enter]"
    return substitute_vars(template, row)


def parse_log_sections(content: str) -> list[LogSection]:
    lines = content.splitlines()
    sections: list[LogSection] = []
    i = 0
    while i < len(lines):
        m = ROW_HEADER_RE.match(lines[i])
        if not m:
            i += 1
            continue
        row_idx = int(m.group(1))
        time = m.group(2)
        csv_line = ""
        i += 1
        if i < len(lines) and lines[i].startswith("CSV: "):
            csv_line = lines[i][5:]
            i += 1
        block: list[str] = []
        while i < len(lines):
            l = lines[i]
            if ROW_HEADER_RE.match(l) or BATCH_HEADER_RE.match(l) or BATCH_END_RE.match(l):
                break
            block.append(l)
            i += 1
        sections.append(LogSection(row_idx, time, csv_line, block))
    return sections


def row_from_csv_line(csv_line: str) -> BatchRow | None:
    fields = parse_csv_line(csv_line)
    if len(fields) < 4:
        return None
    return BatchRow(
        nome_toon=fields[0],
        key_raw=fields[1],
        key_norm=normalize_batch_key(fields[1]),
        vnum_attuale=fields[2],
        vnum_originale=fields[3],
        raw_line=csv_line.strip(),
    )


def section_has_command(block: str, log_label: str) -> bool:
    if not log_label:
        return False
    if f">>> {log_label}" in block:
        return True
    escaped = re.escape(log_label)
    return re.search(rf"\] >>> {escaped}", block) is not None


def verify_section(section: LogSection, row: BatchRow, commands: list[str]) -> list[str]:
    issues: list[str] = []
    block = "\n".join(section.lines)
    for line in section.lines:
        for pat in BATCH_ERROR_PATTERNS:
            if pat in line:
                issues.append(f"errore MUD: {line}")
                break
    for tmpl in commands:
        log_label = prepare_command_log_label(tmpl, row)
        if not section_has_command(block, log_label):
            issues.append(f"comando mancante nel log: {log_label}")
    wants_osave = any("osave" in (c or "").lower() for c in commands)
    if wants_osave:
        expected = (
            f"Ho salvato .+ con il vnum {row.vnum_attuale} "
            f"\\(originale {row.vnum_originale}\\)"
        )
        if not re.search(expected, block):
            m = OSAVE_SUCCESS_RE.search(block)
            if m:
                issues.append(
                    f"osave: atteso vnum {row.vnum_attuale} (orig {row.vnum_originale}), "
                    f"nel log {m.group(1)} (orig {m.group(2)})"
                )
            else:
                issues.append(
                    "messaggio osave di successo non trovato (Ho salvato ... con il vnum ...)"
                )
    return issues


def verify_objects(rows: list[BatchRow], objects_dir: Path) -> list[str]:
    issues: list[str] = []
    if not objects_dir.is_dir():
        return [f"objects-dir non trovata: {objects_dir}"]
    for row in rows:
        obj_path = objects_dir / row.vnum_attuale
        if not obj_path.is_file():
            issues.append(
                f"file oggetto mancante: objects/{row.vnum_attuale} ({row.key_norm})"
            )
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="Verifica log nbatch Nebbie Dashboard")
    parser.add_argument("--csv", required=True, type=Path, help="nebbie-batch-items.csv")
    parser.add_argument("--commands", required=True, type=Path, help="nebbie-batch-commands.txt")
    parser.add_argument("--log", required=True, type=Path, help="Log Toon-YYYY-MM-DD.txt")
    parser.add_argument("--toon", help="Filtra righe CSV per nome-toon")
    parser.add_argument("--objects-dir", type=Path, help="mudroot/lib/objects (opzionale)")
    args = parser.parse_args()

    if not args.log.is_file():
        print(f"ERRORE: log non trovato: {args.log}", file=sys.stderr)
        return 1

    rows = load_csv(args.csv, args.toon)
    commands = commands_with_nchar_prefix(load_commands(args.commands))
    content = args.log.read_text(encoding="utf-8", errors="replace")
    sections = parse_log_sections(content)

    if not sections:
        print("FAIL: nessuna sezione --- riga N --- nel log")
        return 1

    expected = {r.raw_line: r for r in rows}
    all_issues: list[str] = []
    ok_count = 0

    print(f"Log: {args.log}")
    print(f"Sezioni nel log: {len(sections)}")
    print(f"Righe CSV attese: {len(rows)}")
    print()

    seen_csv: set[str] = set()
    for section in sections:
        row = row_from_csv_line(section.csv_line)
        label = f"riga {section.row_idx}"
        if row is None:
            all_issues.append(f"{label}: CSV non parsabile")
            print(f"FAIL {label}: CSV non parsabile")
            continue
        label = f"riga {section.row_idx} ({row.key_norm})"
        if row.raw_line not in expected and rows:
            all_issues.append(f"{label}: non presente nel CSV filtrato")
            print(f"FAIL {label}: non nel CSV atteso")
            continue
        seen_csv.add(row.raw_line)
        issues = verify_section(section, row, commands)
        if issues:
            print(f"FAIL {label}")
            for msg in issues:
                print(f"  - {msg}")
                all_issues.append(f"{label}: {msg}")
        else:
            ok_count += 1
            print(f"OK   {label}")

    for row in rows:
        if row.raw_line not in seen_csv:
            msg = f"riga CSV mai eseguita (assente dal log): {row.raw_line}"
            all_issues.append(msg)
            print(f"FAIL {msg}")

    if "batch terminato: completato" not in content:
        reason_m = re.search(r"--- batch terminato: ([^\n]+) ---", content)
        if reason_m:
            msg = f"batch non completato: {reason_m.group(1)}"
            all_issues.append(msg)
            print(f"FAIL {msg}")

    if args.objects_dir:
        print()
        print(f"Verifica file oggetto in {args.objects_dir}:")
        obj_issues = verify_objects(rows, args.objects_dir)
        for msg in obj_issues:
            print(f"FAIL {msg}")
            all_issues.append(msg)

    print()
    print(f"Risultato: {ok_count}/{len(sections)} sezioni log OK")
    if all_issues:
        print(f"TOTALE problemi: {len(all_issues)}")
        return 1
    print("TUTTO OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
