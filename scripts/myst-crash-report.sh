#!/bin/bash
# Raccoglie log utili dopo un crash/restart di myst.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== myst crash report $(date -Is) ==="
echo ""

echo "--- docker compose ps ---"
docker compose ps 2>/dev/null || true
echo ""

echo "--- consumer logs (ultime 120 righe) ---"
docker compose logs --tail=120 consumer 2>/dev/null || true
echo ""

for log in mudroot/lib/alarmud.log mudroot/lib/errors.log mudroot/lib/query.log; do
  if [ -f "$log" ]; then
    echo "--- tail $log ---"
    tail -60 "$log"
    echo ""
  fi
done

if docker compose ps --status running consumer 2>/dev/null | grep -q consumer; then
  echo "--- myst in container (ps) ---"
  docker compose exec -T consumer ps aux 2>/dev/null | grep -E '[m]yst' || echo "(myst non in esecuzione nel container)"
  echo ""
fi

echo "--- OOM kernel (ultime righe) ---"
dmesg -T 2>/dev/null | grep -iE 'oom|killed process|out of memory' | tail -10 || echo "(nessun OOM recente o dmesg non disponibile)"
echo ""

echo "Codici uscita frequenti:"
echo "  0   = uscita normale (anche dopo SIGTERM / reboot)"
echo "  1   = errore DB/schema o init"
echo "  134 = abort() (es. CHECKPOINT shutdown, affect invalidi)"
echo "  139 = SIGSEGV"
echo ""
echo "Dopo un crash, invia l'output di questo script."
