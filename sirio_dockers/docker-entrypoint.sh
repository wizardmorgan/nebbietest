#!/bin/bash
set -e

MYSQL_DATA_DIR="/var/lib/mysql"
MYSQL_RUN_DIR="/var/run/mysqld"
MYSQL_USER="root"
MYSQL_PASSWORD="secret"
MYSQL_DB="nebbie"
MYSQL_IMPORT_FILE="${MYSQL_IMPORT_FILE:-/docker-init/database_backup.sql}"
MYSQL_EXTRA_FLAGS=""
if [ -n "${MYSQL_LOWER_CASE_TABLE_NAMES:-}" ]; then
  MYSQL_EXTRA_FLAGS="--lower-case-table-names=${MYSQL_LOWER_CASE_TABLE_NAMES}"
fi

echo "Setting up MySQL directories and ownership..."
mkdir -p ${MYSQL_RUN_DIR}
mkdir -p /var/log/mysql
chown -R mysql:mysql ${MYSQL_DATA_DIR} ${MYSQL_RUN_DIR} /var/log/mysql
rm -f ${MYSQL_RUN_DIR}/mysqld.pid

if [ ! -d "${MYSQL_DATA_DIR}/mysql" ]; then
    echo "Initializing MySQL data directory (first run)..."
    su -s /bin/bash mysql -c "/usr/sbin/mysqld --initialize-insecure --user=mysql --datadir=${MYSQL_DATA_DIR} ${MYSQL_EXTRA_FLAGS}"
    echo "Data directory initialized."
fi

echo "Starting MySQL daemon..."
su -s /bin/bash mysql -c "/usr/sbin/mysqld --bind-address=0.0.0.0 --datadir=${MYSQL_DATA_DIR} --socket=${MYSQL_RUN_DIR}/mysqld.sock --pid-file=${MYSQL_RUN_DIR}/mysqld.pid --log-error=/var/log/mysql/error.log ${MYSQL_EXTRA_FLAGS}" &

sleep 3

echo "Waiting for MySQL on 127.0.0.1:3306..."
TIMEOUT=60
for i in $(seq 1 $TIMEOUT); do
  if mysqladmin ping -h 127.0.0.1 -P 3306 --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD > /dev/null 2>&1; then
    echo "MySQL is running."
    break
  fi
  if [ $i -eq $TIMEOUT ]; then
    echo "ERROR: MySQL startup timed out."
    if [ -f /var/log/mysql/error.log ]; then
      sed -n '1,200p' /var/log/mysql/error.log || true
    fi
    exit 1
  fi
  sleep 1
done

echo "Configuring database..."
if ! mysql -h 127.0.0.1 -P 3306 --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DB;"; then
  if ! mysql -h 127.0.0.1 -P 3306 --protocol=TCP -u$MYSQL_USER -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DB;"; then
    echo "ERROR: Failed to create database '$MYSQL_DB'"
    exit 1
  fi
  mysql -h 127.0.0.1 -P 3306 --protocol=TCP -u$MYSQL_USER -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
fi

TABLE_COUNT=$(mysql -h 127.0.0.1 -P 3306 --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD -N -e \
  "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DB}';" 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" = "0" ] && [ -f "$MYSQL_IMPORT_FILE" ]; then
  echo "Importing database from ${MYSQL_IMPORT_FILE}..."
  mysql -h 127.0.0.1 -P 3306 --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD "$MYSQL_DB" < "$MYSQL_IMPORT_FILE"
  echo "Database import completed."
elif [ "$TABLE_COUNT" = "0" ]; then
  echo "WARNING: database '${MYSQL_DB}' is empty and no import file at ${MYSQL_IMPORT_FILE}"
fi

MIGRATION_FLAGS=/app/docs/schema-s1-toon-migration-flags.sql
if [ -f "$MIGRATION_FLAGS" ]; then
  HAS_TOON=$(mysql -h 127.0.0.1 -P 3306 --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD -N -e \
    "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DB}' AND TABLE_NAME='toon';" 2>/dev/null || echo "0")
  if [ "$HAS_TOON" != "0" ]; then
    HAS_MIGRATED_AT=$(mysql -h 127.0.0.1 -P 3306 --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD -N -e \
      "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='${MYSQL_DB}' AND TABLE_NAME='toon' AND COLUMN_NAME='migrated_at';" 2>/dev/null || echo "0")
    if [ "$HAS_MIGRATED_AT" = "0" ]; then
      echo "Applying toon migration flags..."
      mysql -h 127.0.0.1 -P 3306 --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD "$MYSQL_DB" < "$MIGRATION_FLAGS"
    fi
  fi
fi

SERVER_PORT=${SERVER_PORT:-4003}
EXEC_PATH="/app"
DATA_DIR="mudroot/lib"
COMMAND_STRING="cd ${EXEC_PATH} && /app/mudroot/myst -P ${SERVER_PORT} -d ${DATA_DIR}"
echo "Starting application: ${COMMAND_STRING}"
exec su -l vagrant -c "${COMMAND_STRING}"
