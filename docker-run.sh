#!/bin/bash
# Wrapper docker compose — stack dev a 3 servizi (mysql + adminer + consumer).
#
# Uso:
#   ./docker-run.sh up -d              # myst su porta 4000 (default)
#   SERVER_PORT=4003 ./docker-run.sh up -d   # Sirio su 4003 (dopo build.sh sirio-docker)
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
printf 'LOCAL_UID=%s\nLOCAL_GID=%s\nDOCKER_PLATFORM=%s\n' \
    "$LOCAL_UID" "$LOCAL_GID" "$DOCKER_PLATFORM" > "$(dirname "$0")/.env"

echo "DOCKER_PLATFORM=$DOCKER_PLATFORM"
cd "$(dirname "$0")"

# run --rm consumer <cmd> : compila/one-off senza passare dall'entrypoint myst
if [ "${1:-}" = "run" ] && [ "${2:-}" = "--rm" ] && [ "${3:-}" = "consumer" ] && [ $# -ge 4 ]; then
    shift 3
    exec docker compose run --rm --entrypoint "" consumer "$@"
fi

docker compose "$@"
