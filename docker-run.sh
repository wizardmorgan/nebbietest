#!/bin/bash
# Wrapper docker compose — stack dev a 3 servizi (mysql + adminer + consumer).
#
# Uso:
#   ./docker-run.sh up -d              # myst su porta 4000 (default)
#   SERVER_PORT=4003 ./docker-run.sh up -d   # Sirio su 4003 (dopo build.sh sirio-docker)
#   MYSQL_HOST_PORT=33307 ./docker-run.sh up -d   # se la 3306 host e' gia' occupata
#   ./docker-run.sh run --rm consumer ./build.sh devel
#   ./docker-run.sh logs -f consumer

set -e

ARCH=$(uname -m)
OS=$(uname -s)

echo "Host: $OS / $ARCH"

if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    export DOCKER_PLATFORM=linux/amd64
    ODB_FILES=(
        src/odb/account-odb.cxx
        src/odb/account-odb-mysql.cxx
        src/odb/account-schema-mysql.cxx
    )
    NEEDS_ODB=false
    for f in "${ODB_FILES[@]}"; do
        if [ ! -f "$(dirname "$0")/$f" ]; then
            NEEDS_ODB=true
            break
        fi
    done
    if [ "$NEEDS_ODB" = "true" ]; then
        echo "File ODB mancanti — generazione su container ARM64 nativo..."
        docker run --rm --platform linux/arm64 \
            -v "$(cd "$(dirname "$0")" && pwd)/src:/src" \
            ubuntu:24.04 \
            sh -c "
                apt-get update -qq 2>/dev/null
                apt-get install -qq -y g++ odb libodb-dev libodb-boost-dev \
                    libodb-mysql-dev libboost-dev libboost-date-time-dev 2>/dev/null
                cd /src/odb && odb \
                    --profile boost/smart-ptr --profile boost/date-time \
                    --std c++17 -m dynamic -d common -d mysql \
                    --generate-query --generate-prepared --show-sloc \
                    --generate-session --generate-schema \
                    --schema-format separate --at-once \
                    --schema-name account --input-name account account.hpp
            "
        echo "File ODB generati."
    fi
else
    export DOCKER_PLATFORM=linux/amd64
fi

export LOCAL_UID="${LOCAL_UID:-$(id -u)}"
export LOCAL_GID="${LOCAL_GID:-$(id -g)}"

host_port_in_use() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tlnH 2>/dev/null | grep -qE "[:.]${port}[[:space:]]"
        return $?
    fi
    if command -v netstat >/dev/null 2>&1; then
        netstat -tln 2>/dev/null | grep -qE "[:.]${port}[[:space:]]"
        return $?
    fi
    return 1
}

if [ -z "${MYSQL_HOST_PORT:-}" ] && host_port_in_use 3306; then
    export MYSQL_HOST_PORT=33307
    echo "Porta host 3306 occupata: uso MYSQL_HOST_PORT=${MYSQL_HOST_PORT} per questo stack."
elif [ -z "${MYSQL_HOST_PORT:-}" ]; then
    export MYSQL_HOST_PORT=3306
fi

if [ -z "${ADMINER_HOST_PORT:-}" ] && host_port_in_use 8080; then
    export ADMINER_HOST_PORT=8081
    echo "Porta host 8080 occupata: uso ADMINER_HOST_PORT=${ADMINER_HOST_PORT} per Adminer."
elif [ -z "${ADMINER_HOST_PORT:-}" ]; then
    export ADMINER_HOST_PORT=8080
fi

prepare_mysql_data() {
    if [ ! -d mysql_data ]; then
        mkdir -p mysql_data
        echo "Creata directory mysql_data/"
        return
    fi
    if [ -z "$(ls -A mysql_data 2>/dev/null)" ]; then
        return
    fi
    mysql_owner=$(stat -c %u mysql_data 2>/dev/null || stat -f %u mysql_data 2>/dev/null)
    if [ "$mysql_owner" != "999" ] && [ "$mysql_owner" != "0" ]; then
        echo "⚠️  mysql_data/ appartiene a uid $mysql_owner (il container MySQL usa uid 999)."
        echo "    Se mysql non parte, esegui una volta:"
        echo "      ./docker-run.sh down"
        echo "      sudo rm -rf mysql_data/*"
        echo "      SERVER_PORT=${SERVER_PORT:-4000} ./docker-run.sh up -d"
        echo "    Oppure: sudo chown -R 999:999 mysql_data"
    fi
}

if [ "${1:-}" = "up" ]; then
    prepare_mysql_data
fi

printf 'LOCAL_UID=%s\nLOCAL_GID=%s\nDOCKER_PLATFORM=%s\nMYSQL_HOST_PORT=%s\nADMINER_HOST_PORT=%s\nSERVER_PORT=%s\n' \
    "$LOCAL_UID" "$LOCAL_GID" "$DOCKER_PLATFORM" "$MYSQL_HOST_PORT" "$ADMINER_HOST_PORT" \
    "${SERVER_PORT:-4000}" > "$(dirname "$0")/.env"

echo "DOCKER_PLATFORM=$DOCKER_PLATFORM"
echo "MYSQL_HOST_PORT=$MYSQL_HOST_PORT (host -> container mysql:33306)"
echo "ADMINER_HOST_PORT=$ADMINER_HOST_PORT"
echo "SERVER_PORT=${SERVER_PORT:-4000}"
cd "$(dirname "$0")"

myst_lib_ready() {
    [ -f "./mudroot/lib/myst.mob" ]
}

mudlib_source_ready() {
    [ -f "./myst.mob" ]
}

ensure_mudlib() {
    if myst_lib_ready; then
        return 0
    fi
    if mudlib_source_ready && [ -x "./getworldlocal" ]; then
        echo "Copia mudlib (myst.*) in mudroot/lib/..."
        ./getworldlocal
    fi
    myst_lib_ready
}

myst_binary_ready() {
    [ -x "./mudroot/myst" ]
}

will_start_consumer() {
    local has_consumer=false
    local named_services=0
    for arg in "$@"; do
        case "$arg" in
            consumer) has_consumer=true ;;
            mysql|adminer) named_services=$((named_services + 1)) ;;
            -d|--detach|up) ;;
        esac
    done
    if [ "$has_consumer" = true ]; then
        return 0
    fi
    if [ "$named_services" -eq 0 ]; then
        return 0
    fi
    return 1
}

print_build_instructions() {
    echo ""
    echo "=== mudroot/myst non compilato ==="
    echo "Il servizio consumer (il MUD) non puo' partire senza build."
    echo ""
    echo "  1. Compila (prima volta: anche 15-30 minuti):"
    echo "       ./docker-run.sh run --rm consumer ./build.sh sirio-docker"
    echo ""
    echo "  2. Importa il DB se hai il dump (consigliato):"
    echo "       ./scripts/import-mysql-dump.sh ~/docker-vms/database_backup_2306.sql"
    echo ""
    echo "  3. Avvia tutto:"
    echo "       SERVER_PORT=4003 ./docker-run.sh up -d"
    echo ""
    echo "Oppure tutto in uno:"
    echo "       SERVER_PORT=4003 ./scripts/docker-mud-up.sh"
    echo ""
}

cmd_doctor() {
    echo "=== Docker MUD doctor ==="
    docker compose ps
    echo ""
    if myst_binary_ready; then
        echo "OK  mudroot/myst presente"
        ls -la ./mudroot/myst
    else
        echo "MISS mudroot/myst — esegui build (vedi sopra)"
    fi
    if [ -f ./mudroot/lib/myst.mob ]; then
        echo "OK  mudlib (mudroot/lib/myst.mob)"
    elif [ -f ./myst.mob ]; then
        echo "WARN myst.mob in root ma non in mudroot/lib — esegui: ./getworldlocal"
    else
        echo "MISS mudlib — ./getworld (scp) o copia myst.* in mudroot/lib/"
    fi
    echo ""
    echo "Log consumer:"
    docker compose logs --tail=40 consumer 2>/dev/null || true
    echo ""
    echo "Diagnostica avvio myst:"
    echo "  SERVER_PORT=${SERVER_PORT:-4000} ./scripts/myst-boot-check.sh"
    echo "  docker compose run --rm --entrypoint /bin/bash consumer -c \\"
    echo "    'SERVER_PORT=${SERVER_PORT:-4000} ./scripts/myst-boot-check.sh'"
}

if [ "${1:-}" = "doctor" ]; then
    cmd_doctor
    exit 0
fi

if [ "${1:-}" = "up" ] && will_start_consumer "$@" && printf '%s\n' "$@" | grep -qE '(^| )-d($| )'; then
    ensure_mudlib || true
    if ! myst_binary_ready; then
        print_build_instructions
        echo "Avvio solo mysql e adminer (senza MUD)..."
        docker compose up -d mysql adminer
        exit 1
    fi
    if ! myst_lib_ready; then
        echo ""
        echo "=== mudlib mancante in mudroot/lib/ ==="
        echo "  ./getworldlocal"
        echo "  SERVER_PORT=${SERVER_PORT:-4003} ./docker-run.sh up -d consumer"
        echo ""
        exit 1
    fi
fi

# run --rm consumer <cmd> : compila/one-off senza passare dall'entrypoint myst
if [ "${1:-}" = "run" ] && [ "${2:-}" = "--rm" ] && [ "${3:-}" = "consumer" ] && [ $# -ge 4 ]; then
    shift 3
    exec docker compose run --rm --entrypoint "" consumer "$@"
fi

docker compose "$@"
