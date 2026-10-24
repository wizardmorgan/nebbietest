#!/bin/bash
# Diagnostica avvio myst (host o container consumer). Non modifica nulla.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SERVER_PORT="${SERVER_PORT:-4000}"
DATA_DIR="${DATA_DIR:-mudroot/lib}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_DB="${MYSQL_DB:-${MYSQL_DATABASE:-nebbie}}"

# mysql:33306 funziona solo nella rete Docker; sull'host usare 127.0.0.1:<porta mappata>.
RUN_CONTEXT="host"
if [ -f /.dockerenv ]; then
  RUN_CONTEXT="container"
elif getent hosts mysql >/dev/null 2>&1; then
  RUN_CONTEXT="docker-network"
fi

if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
fi

resolve_mysql_endpoint() {
  if [ -n "${MYSQL_HOST:-}" ] && [ -n "${MYSQL_PORT:-}" ]; then
    return 0
  fi
  case "$RUN_CONTEXT" in
    container|docker-network)
      MYSQL_HOST="${MYSQL_HOST:-mysql}"
      MYSQL_PORT="${MYSQL_PORT:-33306}"
      ;;
    host)
      MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
      MYSQL_PORT="${MYSQL_PORT:-${MYSQL_HOST_PORT:-3306}}"
      ;;
  esac
}

resolve_mysql_endpoint

mysql_ping() {
  if command -v mysql >/dev/null 2>&1; then
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1" >/dev/null 2>&1
    return $?
  fi
  if command -v docker >/dev/null 2>&1 && docker compose ps --status running mysql 2>/dev/null | grep -q mysql; then
    docker compose exec -T mysql mysqladmin ping -h 127.0.0.1 -P 33306 \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" >/dev/null 2>&1
    return $?
  fi
  return 2
}

mysql_query() {
  local sql="$1"
  if command -v mysql >/dev/null 2>&1; then
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "$sql" 2>/dev/null
    return $?
  fi
  if command -v docker >/dev/null 2>&1; then
    docker compose exec -T mysql mysql -h 127.0.0.1 -P 33306 \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "$sql" 2>/dev/null
    return $?
  fi
  return 1
}

echo "=== myst boot check ==="
echo "contesto: $RUN_CONTEXT"
echo "SERVER_PORT=$SERVER_PORT  DATA_DIR=$DATA_DIR"
echo "MYSQL=${MYSQL_USER}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}"
if [ "$RUN_CONTEXT" = "host" ]; then
  echo "NOTA: sull'host MySQL e' su 127.0.0.1:${MYSQL_PORT} (non mysql:33306)"
  echo "      Per test identico al consumer:"
  echo "      docker compose run --rm --entrypoint /bin/bash consumer -c 'SERVER_PORT=${SERVER_PORT} ./scripts/myst-boot-check.sh'"
fi
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
  echo "FAIL mudlib — copia myst.* di produzione in ${DATA_DIR}/ e ./scripts/prepare-mudlib.sh"
  fail=1
fi

if grep -q '^#18072' "./${DATA_DIR}/myst.obj" 2>/dev/null \
    && grep -qF 'toxic extract estratto tossico' "./${DATA_DIR}/myst.obj" 2>/dev/null; then
  echo "OK  ingredienti ladro #18072 in ${DATA_DIR}/myst.obj"
else
  echo "WARN ingredienti ladro non trovati — ./scripts/apply-production-world-patch.sh"
fi

for v in 18072 18001 18002 18003 18073 18074; do
  if [ -f "./${DATA_DIR}/objects/$v" ]; then
    echo "WARN overlay ${DATA_DIR}/objects/$v presente — vnum ladro non utilizzabile (non cancellare overlay)"
  fi
done

if ./scripts/apply-thief-world-patch.sh --dir "./${DATA_DIR}" --check 2>/dev/null; then
  echo "OK  patch crafting ladro (--check)"
else
  echo "WARN patch crafting ladro incompleta — ./scripts/apply-production-world-patch.sh"
fi

if [ -x ./scripts/validate-helptbl.sh ]; then
  if ./scripts/validate-helptbl.sh "./${DATA_DIR}"; then
    :
  else
    echo "FAIL helptbl corrotto — git checkout -- pages/helptbl && ./scripts/apply-production-world-patch.sh"
    fail=1
  fi
fi

if [ -f "./${DATA_DIR}/myst.pid" ]; then
  pid="$(tr -d ' \n' < "./${DATA_DIR}/myst.pid" 2>/dev/null || true)"
  echo "INFO myst.pid in lib = '${pid}' (solo informativo, non letto al boot)"
fi

mysql_rc=0
mysql_ping || mysql_rc=$?
if [ "$mysql_rc" -eq 0 ]; then
  echo "OK  MySQL raggiungibile (${MYSQL_HOST}:${MYSQL_PORT})"
  tables="$(mysql_query "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DB}';" || echo "?")"
  echo "    tabelle in ${MYSQL_DB}: ${tables}"
  if [ "${tables:-0}" = "0" ] || [ "$tables" = "?" ]; then
    echo "WARN database vuoto o schema assente — importa il dump:"
    echo "      ./scripts/import-mysql-dump.sh /path/to/database_backup.sql"
  fi
elif [ "$mysql_rc" -eq 2 ]; then
  echo "SKIP client mysql assente — verifica con:"
  echo "      docker compose exec mysql mysqladmin ping -h 127.0.0.1 -P 33306 -uroot -psecret"
else
  echo "FAIL MySQL non raggiungibile su ${MYSQL_HOST}:${MYSQL_PORT}"
  if [ "$RUN_CONTEXT" = "host" ]; then
    echo "      Avvia lo stack: SERVER_PORT=${SERVER_PORT} ./docker-run.sh up -d mysql"
    echo "      Oppure: MYSQL_HOST=127.0.0.1 MYSQL_HOST_PORT=\$(grep MYSQL_HOST_PORT .env) ./scripts/myst-boot-check.sh"
  fi
  fail=1
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

if [ "$RUN_CONTEXT" = "host" ] && ! command -v mysql >/dev/null 2>&1; then
  echo "=== prova avvio myst (solo nel container consumer) ==="
  echo "Sull'host senza client mysql, esegui:"
  echo "  docker compose run --rm --entrypoint /bin/bash consumer -c 'SERVER_PORT=${SERVER_PORT} ./scripts/myst-boot-check.sh'"
  exit 0
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
  echo "OK  myst ha completato il boot ed era in game loop dopo 15s."
  echo ""
  echo "ATTENZIONE: il test ha terminato myst (SIGTERM). Non e' piu' in ascolto."
  echo "Per giocare, avvia il servizio persistente:"
  echo "  SERVER_PORT=${SERVER_PORT} ./docker-run.sh up -d consumer"
  echo "  telnet localhost ${SERVER_PORT}"
  echo ""
  echo "Verifica: ./docker-run.sh doctor"
  exit 0
fi

echo "FAIL myst terminato con codice $rc"
echo "Cause frequenti:"
echo "  - FATAL: cannot initialize MySQL/ODB schema  -> importa dump o verifica MYSQL_*"
echo "  - bind: Address already in use               -> SERVER_PORT occupata"
echo "  - Opening mob file                           -> ./scripts/prepare-mudlib.sh"
echo ""
echo "Log completo consumer:"
echo "  ./docker-run.sh logs --tail=100 consumer"
exit "$rc"
