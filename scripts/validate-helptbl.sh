#!/bin/bash
# Verifica che helptbl/wizhelptbl siano ben formati (evita boot bloccato in build_help_index).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${1:-$ROOT/mudroot/lib}"

validate_one() {
  local path="$1"
  local label="$2"
  if [ ! -f "$path" ]; then
    echo "FAIL $label: file mancante ($path)"
    return 1
  fi
  if grep -q '^<<<<<<<\|^=======\|^>>>>>>>' "$path" 2>/dev/null; then
    echo "FAIL $label: marker di conflitto git in $path"
    return 1
  fi
  if ! grep -q '#~' "$path" 2>/dev/null; then
    echo "FAIL $label: manca terminatore #~ in $path"
    return 1
  fi
  python3 - "$path" "$label" <<'PY'
import sys
path, label = sys.argv[1], sys.argv[2]
with open(path, "rb") as f:
    data = f.read()
text = data.decode("latin-1", errors="replace")
lines = text.splitlines()
i = 0
entries = 0
while i < len(lines):
    if not lines[i].strip() and entries == 0 and i == 0:
        i += 1
        continue
    entries += 1
    i += 1
    while i < len(lines):
        if lines[i].startswith("#"):
            if lines[i].startswith("#~"):
                print(f"OK  {label}: {entries} voci, {len(lines)} righe")
                sys.exit(0)
            i += 1
            break
        i += 1
    else:
        print(f"FAIL {label}: voce {entries} senza terminatore # (file troncato?)")
        sys.exit(1)
print(f"FAIL {label}: EOF senza #~")
sys.exit(1)
PY
}

fail=0
validate_one "$DATA_DIR/helptbl" "helptbl" || fail=1
if [ -f "$DATA_DIR/wizhelptbl" ]; then
  validate_one "$DATA_DIR/wizhelptbl" "wizhelptbl" || fail=1
fi
exit "$fail"
