#!/bin/bash
# Avvia myst nel servizio consumer (MySQL esterno su servizio compose "mysql").
# Con argomenti (es. docker compose run consumer ./build.sh devel) esegue il comando.
set -euo pipefail

exec 1>&2

# docker compose run consumer ./build.sh ... passa il comando come argomenti all'entrypoint
if [ "$#" -gt 0 ]; then
  echo "[consumer] running command: $*"
  exec "$@"
fi

echo "[consumer] entrypoint start (pid $$, user $(id -un))"

MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-33306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
SERVER_PORT="${SERVER_PORT:-4000}"
DATA_DIR="${DATA_DIR:-mudroot/lib}"

mysql_ready() {
  if command -v mysqladmin >/dev/null 2>&1; then
    if mysqladmin ping -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
        -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" >/dev/null 2>&1; then
      return 0
    fi
  fi
  if command -v mysql >/dev/null 2>&1; then
    if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
        -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
      return 0
    fi
  fi
  # Fallback: porta TCP aperta (non verifica auth)
  if (exec 3<>/dev/tcp/"$MYSQL_HOST"/"$MYSQL_PORT") 2>/dev/null; then
    exec 3<&-
    exec 3>&-
    return 0
  fi
  return 1
}

echo "[consumer] waiting for MySQL at ${MYSQL_HOST}:${MYSQL_PORT}..."
TIMEOUT=120
for i in $(seq 1 "$TIMEOUT"); do
  if mysql_ready; then
    echo "[consumer] MySQL is ready."
    break
  fi
  if [ "$i" -eq "$TIMEOUT" ]; then
    echo "[consumer] ERROR: MySQL not reachable at ${MYSQL_HOST}:${MYSQL_PORT}"
    echo "[consumer] Debug: try from host:"
    echo "  docker compose exec mysql mysqladmin ping -h 127.0.0.1 -P 33306 -uroot -psecret"
    echo "  docker compose run --rm --entrypoint /bin/bash consumer -c 'mysql -hmysql -P33306 -uroot -psecret -e \"SELECT 1\"'"
    exit 1
  fi
  sleep 1
done

if [ ! -x /app/mudroot/myst ]; then
  echo "[consumer] ERROR: /app/mudroot/myst not found. Build first:"
  echo "  ./docker-run.sh run --rm consumer ./build.sh devel"
  echo "  ./docker-run.sh run --rm consumer ./build.sh sirio-docker"
  exit 1
fi

if [ ! -f /app/mudroot/lib/myst.mob ]; then
  if [ -f /app/myst.mob ]; then
    echo "[consumer] mudlib assente in mudroot/lib — copia da ./getworldlocal"
    if [ -x /app/getworldlocal ]; then
      /app/getworldlocal
    else
      cp -v /app/myst.mob /app/myst.obj /app/myst.wld /app/myst.zon /app/myst.spe /app/myst.shp /app/mudroot/lib/ 2>/dev/null || true
    fi
  fi
fi

if [ ! -f /app/mudroot/lib/myst.mob ]; then
  echo "[consumer] ERROR: /app/mudroot/lib/myst.mob missing (mudlib not installed)."
  echo "[consumer] Dalla root del repo esegui: ./getworldlocal"
  echo "[consumer]   (copia myst.mob myst.obj myst.wld ... da /app/ a mudroot/lib/)"
  exit 1
fi

export MYSQL_HOST MYSQL_PORT MYSQL_USER MYSQL_PASSWORD MYSQL_DB="${MYSQL_DB:-nebbie}"

cd /app

if command -v ss >/dev/null 2>&1; then
  if ss -tlnH 2>/dev/null | grep -qE "[:.]${SERVER_PORT}[[:space:]]"; then
    echo "[consumer] ERROR: port ${SERVER_PORT} already in use inside the container."
    echo "[consumer] Stop the other myst or use a different SERVER_PORT."
    ss -tlnp 2>/dev/null | grep -E "[:.]${SERVER_PORT}[[:space:]]" || true
    exit 1
  fi
fi

if command -v mysql >/dev/null 2>&1; then
  if ! mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE \`${MYSQL_DB}\`" >/dev/null 2>&1; then
    echo "[consumer] ERROR: database '${MYSQL_DB}' missing or not accessible."
    echo "[consumer] Import a dump, e.g.:"
    echo "  ./scripts/import-mysql-dump.sh ~/docker-vms/database_backup_2306.sql"
    exit 1
  fi
  table_count="$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
    -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e \
    "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DB}';" 2>/dev/null || echo 0)"
  if [ "${table_count:-0}" -lt 5 ]; then
    echo "[consumer] WARN: only ${table_count} tables in ${MYSQL_DB}."
    echo "[consumer] myst may exit with: FATAL: cannot initialize MySQL/ODB schema"
    echo "[consumer] Recommended: ./scripts/import-mysql-dump.sh <dump.sql>"
  fi
fi

echo "[consumer] starting myst -P ${SERVER_PORT} -d ${DATA_DIR}"
echo "[consumer] on failure run: ./scripts/myst-boot-check.sh"
exec /app/mudroot/myst -P "${SERVER_PORT}" -d "${DATA_DIR}" -v 4
