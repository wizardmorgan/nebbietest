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

echo "--- consumer logs (ultime 150 righe) ---"
docker compose logs --tail=150 consumer 2>/dev/null || true
echo ""

for log in mudroot/lib/alarmud.log mudroot/lib/errors.log mudroot/lib/query.log; do
  if [ -f "$log" ]; then
    echo "--- tail $log ---"
    tail -80 "$log"
    echo ""
  fi
done

echo "--- crash context (alarmud.log su host) ---"
if [ -f mudroot/lib/alarmud.log ]; then
  grep -E 'SIGSEGV|SIGBUS|MYST SIG|LastTrack|Mud status when crashed|Last Name|Calling Stack|CHECKPOINT shutdown|thief_poison|thief_on_hit' \
    mudroot/lib/alarmud.log 2>/dev/null | tail -50 || true
fi
echo ""

echo "--- crash context (docker logs) ---"
docker compose logs consumer 2>/dev/null | grep -E \
  "SIGSEGV|SIGBUS|MYST SIG|myst exited|Mud status when crashed|LastTrack|Last Name|Calling Stack|CHECKPOINT shutdown|thief_poison|thief_on_hit" \
  | tail -40 || true
echo ""

if docker compose ps --status running consumer 2>/dev/null | grep -q consumer; then
  echo "--- myst in container (ps) ---"
  docker compose exec -T consumer ps aux 2>/dev/null | grep -E '[m]yst' || echo "(myst non in esecuzione nel container)"
  echo ""
fi

echo "--- OOM / kernel ---"
dmesg -T 2>/dev/null | grep -iE 'oom|killed process|out of memory|segfault.*myst' | tail -10 \
  || echo "(nessun OOM/segfault kernel recente o dmesg non disponibile)"
echo ""

echo "--- core dump (di solito assente in Docker) ---"
docker compose exec -T consumer bash -lc 'ulimit -c; ls -la /app/core* /app/mudroot/core* 2>/dev/null; cat /proc/sys/kernel/core_pattern 2>/dev/null' 2>/dev/null \
  || echo "(container non raggiungibile)"
echo ""

echo "Codici uscita myst:"
echo "  0   = uscita normale (anche dopo SIGTERM / reboot)"
echo "  1   = errore DB/schema o init"
echo "  134 = abort() — CHECKPOINT, assert, affect invalidi (non sempre SIGSEGV)"
echo "  139 = SIGSEGV (segmentation fault)"
echo ""
echo "=== Come investigare (senza core dump) ==="
echo "1. Subito dopo il crash:"
echo "     ./scripts/myst-crash-report.sh > crash-$(date +%Y%m%d-%H%M).txt"
echo "2. Cerca in alarmud.log:"
echo "     grep -E 'LastTrack|Mud status|Calling Stack|thief_' mudroot/lib/alarmud.log | tail -30"
echo "3. Ripeti il crash sotto gdb (consigliato):"
echo "     SERVER_PORT=4003 docker compose stop consumer"
echo "     SERVER_PORT=4003 docker compose run --rm -it --entrypoint bash consumer"
echo "     ulimit -c unlimited"
echo "     cd /app && ./mudroot/myst -P 4003 -d mudroot/lib -v 4"
echo "     # dopo crash, in altro terminale:"
echo "     gdb -batch -ex 'bt full' /app/mudroot/myst /app/core"
echo ""
echo "Per core dump in Docker servono anche ulimits in compose e spesso"
echo "kernel.core_pattern sull'host — i log myst (sopra) sono più semplici."
echo ""
echo "Invia l'output di questo script dopo un crash in combattimento."
