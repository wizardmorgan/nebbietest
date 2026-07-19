#!/bin/bash
# Wrapper docker compose per ambiente Sirio (porta 4003).
#
# Uso (da sirio_dockers/):
#   ./docker-run.sh build
#   ./docker-run.sh up -d
#   ./docker-run.sh down
#   ./docker-run.sh logs -f

set -e

SIRO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SIRO_DIR}/.." && pwd)"
ARCH=$(uname -m)

echo "Sirio Docker — host arch: ${ARCH}"
echo "Server root: ${ROOT}"

if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    export DOCKER_PLATFORM=linux/amd64
    ODB_FILES=(
        src/odb/account-odb.cxx
        src/odb/account-odb-mysql.cxx
        src/odb/account-schema-mysql.cxx
    )
    NEEDS_ODB=false
    for f in "${ODB_FILES[@]}"; do
        if [ ! -f "${ROOT}/${f}" ]; then
            NEEDS_ODB=true
            break
        fi
    done
    if [ "$NEEDS_ODB" = "true" ]; then
        echo "File ODB mancanti — generazione su container ARM64..."
        docker run --rm --platform linux/arm64 \
            -v "${ROOT}/src:/src" \
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
    fi
else
    export DOCKER_PLATFORM=linux/amd64
fi

echo "DOCKER_PLATFORM=${DOCKER_PLATFORM}"
cd "${SIRO_DIR}"
docker compose "$@"
