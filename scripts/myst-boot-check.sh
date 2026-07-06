#!/bin/bash
# Diagnostica avvio myst (Docker consumer o host). Non modifica nulla.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SERVER_PORT="${SERVER_PORT:-4000}"
DATA_DIR="${DATA_DIR:-mudroot/lib}"
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-33306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_DB="${MYSQL_DB:-${MYSQL_DATABASE:-nebbie}}"

echo "=== myst boot check ==="
echo "SERVER_PORT=$SERVER_PORT  DATA_DIR=$DATA_DIR"
echo "MYSQL=${MYSQL_USER}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}"
echo ""

fail=0

if [ -x ./mudroot/myst ]; then
  echo "OK  mudroot/myst"
  ls -la ./mudroot/myst
else
  echo "FAIL mudroot/myst assente — build:"
  echo "      ./docker-run.sh run --rm consumer ./build.sh sirio-docker"
  fail=1
fi

if [ -f "./${DATA_DIR}/myst.mob" ]; then
  echo "OK  ${DATA_DIR}/myst.mob"
else
  echo "FAIL mudlib — ./getworldlocal"
  fail=1
fi

if grep -q '^#18500' myst.obj 2>/dev/null; then
  echo "OK  ingredienti ladro #18500 in myst.obj (root)"
else
  echo "WARN #18500 non trovato in myst.obj root"
fi

if [ -f "./${DATA_DIR}/myst.pid" ]; then
  pid="$(tr -d ' \n' < "./${DATA_DIR}/myst.pid" 2>/dev/null || true)"
  echo "INFO myst.pid in lib = '${pid}' (solo informativo, non letto al boot)"
fi

if command -v mysql >/dev/null 2>&1; then
  if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
    echo "OK  MySQL raggiungibile"
    tables="$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e \
      "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DB}';" 2>/dev/null || echo "?")"
    echo "    tabelle in ${MYSQL_DB}: ${tables}"
    if [ "${tables:-0}" = "0" ] || [ "$tables" = "?" ]; then
      echo "WARN database vuoto o schema assente — importa il dump:"
      echo "      ./scripts/import-mysql-dump.sh /path/to/database_backup.sql"
    fi
  else
    echo "FAIL MySQL non raggiungibile su ${MYSQL_HOST}:${MYSQL_PORT}"
    fail=1
  fi
else
  echo "SKIP mysql client non installato (normale fuori dal container)"
fi

if command -v ss >/dev/null 2>&1; then
  if ss -tlnH 2>/dev/null | grep -qE "[:.]${SERVER_PORT}[[:space:]]"; then
    echo "FAIL porta ${SERVER_PORT} gia' in uso (myst gia' avviato o altro processo)"
    ss -tlnp 2>/dev/null | grep -E "[:.]${SERVER_PORT}[[:space:]]" || true
    fail=1
  else
    echo "OK  porta ${SERVER_PORT} libera"
  fi
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "Correggi i FAIL sopra, poi riprova."
  exit 1
fi

echo "=== prova avvio myst (15s, cattura stderr) ==="
if [ ! -x ./mudroot/myst ]; then
  exit 1
fi

export MYSQL_HOST MYSQL_PORT MYSQL_USER MYSQL_PASSWORD MYSQL_DB
log="$(mktemp)"
set +e
timeout 15 ./mudroot/myst -P "$SERVER_PORT" -d "$DATA_DIR" -v 4 >"$log" 2>&1
rc=$?
set -e
tail -80 "$log"
rm -f "$log"

echo ""
if [ "$rc" -eq 124 ]; then
  echo "OK  myst ancora in esecuzione dopo 15s (probabile boot riuscito)"
  exit 0
fi

echo "FAIL myst terminato con codice $rc"
echo "Cause frequenti:"
echo "  - FATAL: cannot initialize MySQL/ODB schema  -> importa dump o verifica MYSQL_*"
echo "  - bind: Address already in use               -> SERVER_PORT occupata"
echo "  - Opening mob file                           -> ./getworldlocal"
echo ""
echo "Log completo consumer:"
echo "  ./docker-run.sh logs --tail=100 consumer"
exit "$rc"
