#!/bin/bash
# Avvio completo stack MUD in Docker: mysql -> build myst -> import DB (opz.) -> consumer.
#
# Uso:
#   SERVER_PORT=4003 ./scripts/docker-mud-up.sh
#   MYSQL_DUMP=~/dump.sql SERVER_PORT=4003 ./scripts/docker-mud-up.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export SERVER_PORT="${SERVER_PORT:-4003}"
export MYSQL_DUMP="${MYSQL_DUMP:-${HOME}/docker-vms/database_backup_2306.sql}"

echo "==> 1/4 MySQL"
./docker-run.sh up -d mysql

echo "==> 2/5 Mudlib"
if ! [ -f ./mudroot/lib/myst.mob ]; then
    if [ -n "${MYST_WORLD_SRC:-}" ]; then
        ./scripts/apply-production-world-patch.sh
    elif [ -f ./myst.mob ] && [ -x ./getworldlocal ]; then
        ./getworldlocal
    else
        echo "ERRORE: myst.mob non trovato in mudroot/lib"
        echo "  Dev:        ./getworldlocal"
        echo "  Produzione: cp /path/produzione/myst.* mudroot/lib/"
        echo "              ./scripts/apply-production-world-patch.sh --flavor"
        exit 1
    fi
elif [ -x ./scripts/apply-production-world-patch.sh ]; then
    ./scripts/apply-production-world-patch.sh --check 2>/dev/null \
        || ./scripts/apply-production-world-patch.sh
fi

echo "==> 3/5 Build myst (sirio-docker, porta ${SERVER_PORT})"
if [ ! -x ./mudroot/myst ]; then
    ./docker-run.sh run --rm consumer ./build.sh sirio-docker
else
    echo "    mudroot/myst gia' presente, salto build"
fi

echo "==> 4/5 Database"
if [ -f "$MYSQL_DUMP" ]; then
    ./scripts/import-mysql-dump.sh "$MYSQL_DUMP"
else
    echo "    Nessun dump in MYSQL_DUMP=$MYSQL_DUMP — salto import"
    echo "    (il MUD potrebbe richiedere schema/tabelle: importa un dump se myst non parte)"
fi

echo "==> 5/5 Avvio consumer (MUD)"
./docker-run.sh up -d consumer

echo ""
echo "Attendo porta ${SERVER_PORT}..."
for i in $(seq 1 45); do
    if command -v ss >/dev/null 2>&1 && ss -tlnH 2>/dev/null | grep -qE "[:.]${SERVER_PORT}[[:space:]]"; then
        echo "OK — in ascolto su ${SERVER_PORT}"
        echo "  telnet localhost ${SERVER_PORT}"
        exit 0
    fi
    if ! docker compose ps --status running 2>/dev/null | grep -q consumer; then
        echo "ERRORE: consumer non in esecuzione. Log:"
        docker compose logs --tail=50 consumer
        exit 1
    fi
    sleep 2
done

echo "Timeout in attesa della porta ${SERVER_PORT}."
echo "Diagnostica: ./docker-run.sh doctor"
docker compose logs --tail=50 consumer
exit 1
