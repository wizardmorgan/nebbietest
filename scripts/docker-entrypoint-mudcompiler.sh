#!/bin/bash
# Avvio myst nel container mudcompiler (stack docker-compose con mysql esterno).
set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-33306}"
SERVER_PORT="${SERVER_PORT:-4000}"
DATA_DIR="${DATA_DIR:-mudroot/lib}"
EDIT_API_PORT="${EDIT_API_PORT:-8090}"
EDIT_API_SECRET="${EDIT_API_SECRET:-nebbie-edit-dev-secret}"

echo "[mudcompiler] waiting MySQL ${MYSQL_HOST}:${MYSQL_PORT}..."
for i in $(seq 1 90); do
  if mysqladmin ping -h "$MYSQL_HOST" -P "$MYSQL_PORT" -uroot -p"${MYSQL_PASSWORD:-secret}" --silent 2>/dev/null; then
    echo "[mudcompiler] MySQL ready."
    break
  fi
  if [ "$i" -eq 90 ]; then
    echo "[mudcompiler] ERROR: MySQL timeout" >&2
    exit 1
  fi
  sleep 2
done

export EDIT_API_PORT EDIT_API_SECRET

if [ ! -x /app/mudroot/myst ]; then
  echo "[mudcompiler] ERROR: /app/mudroot/myst missing. Build first:" >&2
  echo "  docker compose run --rm --entrypoint '' mudcompiler ./build.sh devel" >&2
  exit 1
fi

if [ ! -f "/app/${DATA_DIR}/myst.mob" ]; then
  echo "[mudcompiler] ERROR: mudlib missing at /app/${DATA_DIR}/myst.mob" >&2
  exit 1
fi

cd /app
echo "[mudcompiler] starting myst port ${SERVER_PORT}, edit-api ${EDIT_API_PORT}"
exec /app/mudroot/myst -P "${SERVER_PORT}" -d "${DATA_DIR}" -v 4
