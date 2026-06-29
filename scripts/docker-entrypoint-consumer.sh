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
  echo "[consumer] ERROR: /app/mudroot/lib/myst.mob missing (mudlib not installed)."
  exit 1
fi

export MYSQL_HOST MYSQL_PORT MYSQL_USER MYSQL_PASSWORD MYSQL_DB="${MYSQL_DB:-nebbie}"

cd /app
echo "[consumer] starting myst -P ${SERVER_PORT} -d ${DATA_DIR}"
exec /app/mudroot/myst -P "${SERVER_PORT}" -d "${DATA_DIR}" -v 4
