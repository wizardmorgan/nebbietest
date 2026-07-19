#!/bin/bash
# Prepara mudroot/lib e il symlink al dump SQL prima del primo avvio.
# Eseguire una volta sulla macchina host (nucbuntu).
#
# Variabili opzionali:
#   MONTERO_LIB  — sorgente mudroot/lib (default: /home/nebbie/monterotest/Server/mudroot/lib)
#   DB_DUMP      — dump SQL (default: /home/nebbie/docker-vms/database_backup_2306.sql)

set -euo pipefail

SIRO_DIR="$(cd "$(dirname "$0")" && pwd)"
MONTERO_LIB="${MONTERO_LIB:-/home/nebbie/monterotest/Server/mudroot/lib}"
DB_DUMP="${DB_DUMP:-/home/nebbie/docker-vms/database_backup_2306.sql}"
DEST_LIB="${SIRO_DIR}/mudroot/lib"
INIT_DIR="${SIRO_DIR}/init"

echo "Sirio setup-data"
echo "  sorgente lib: ${MONTERO_LIB}"
echo "  destinazione: ${DEST_LIB}"
echo "  dump SQL:     ${DB_DUMP}"

for path in "${MONTERO_LIB}" "${DB_DUMP}"; do
  if [ ! -e "${path}" ]; then
    echo "ERROR: percorso non trovato: ${path}" >&2
    exit 1
  fi
done

mkdir -p "${DEST_LIB}" "${INIT_DIR}"

echo "Copia completa mudroot/lib..."
rsync -a --delete "${MONTERO_LIB}/" "${DEST_LIB}/"

echo "Symlink dump SQL..."
ln -sfn "${DB_DUMP}" "${INIT_DIR}/database_backup.sql"

echo "Setup completato."
echo "Prossimi passi:"
echo "  cd ${SIRO_DIR}"
echo "  ./docker-run.sh build"
echo "  ./docker-run.sh up -d"
