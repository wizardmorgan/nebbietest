#!/bin/bash
# Importa un dump SQL nel MySQL del compose a 3 servizi (servizio mysql).
#
# Uso:
#   ./scripts/import-mysql-dump.sh /path/to/database_backup.sql
#   ./scripts/import-mysql-dump.sh   # default: ~/docker-vms/database_backup_2306.sql
#
# ATTENZIONE: ricrea il database nebbie (DROP + CREATE). Ferma il consumer prima.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DUMP="${1:-${HOME}/docker-vms/database_backup_2306.sql}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_DB="${MYSQL_DB:-nebbie}"

if [ ! -f "$DUMP" ]; then
  echo "ERROR: dump non trovato: $DUMP"
  echo "  Passa il percorso: ./scripts/import-mysql-dump.sh /path/to/dump.sql"
  exit 1
fi

echo "Dump: $DUMP"
echo "Avvio solo mysql..."
./docker-run.sh up -d mysql

echo "Attendo MySQL..."
for i in $(seq 1 60); do
  if docker compose exec -T mysql mysqladmin ping -h 127.0.0.1 -P 33306 \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Ricreo database ${MYSQL_DB}..."
docker compose exec -T mysql mysql -h 127.0.0.1 -P 33306 \
  -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
  -e "DROP DATABASE IF EXISTS \`${MYSQL_DB}\`; CREATE DATABASE \`${MYSQL_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "Import in corso (può richiedere minuti)..."
docker compose exec -T mysql mysql -h 127.0.0.1 -P 33306 \
  -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" < "$DUMP"

echo "Verifica tabelle..."
docker compose exec -T mysql mysql -h 127.0.0.1 -P 33306 \
  -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e \
  "SELECT COUNT(*) AS tables_in_nebbie FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DB}';"

docker compose exec -T mysql mysql -h 127.0.0.1 -P 33306 \
  -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e \
  "SELECT COUNT(*) AS users FROM ${MYSQL_DB}.user;" 2>/dev/null \
  || docker compose exec -T mysql mysql -h 127.0.0.1 -P 33306 \
  -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e \
  "SELECT COUNT(*) AS registered FROM ${MYSQL_DB}.registered;" 2>/dev/null \
  || echo "(tabella user/registered: verifica manualmente lo schema del dump)"

echo ""
echo "OK. Ora:"
echo "  SERVER_PORT=4003 ./docker-run.sh up -d"
echo "  telnet localhost 4003"
