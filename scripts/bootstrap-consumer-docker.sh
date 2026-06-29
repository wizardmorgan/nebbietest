#!/bin/bash
# Applica il fix consumer Docker (entrypoint myst + MySQL esterno).
# Eseguire dalla root del repo Server su Linux:
#   bash scripts/bootstrap-consumer-docker.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p scripts Confs

cat > scripts/docker-entrypoint-consumer.sh <<'EOF'
#!/bin/bash
set -euo pipefail
exec 1>&2
echo "[consumer] entrypoint start (pid $$, user $(id -un))"
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-33306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
SERVER_PORT="${SERVER_PORT:-4000}"
DATA_DIR="${DATA_DIR:-mudroot/lib}"
mysql_ready() {
  if command -v mysqladmin >/dev/null 2>&1; then
    mysqladmin ping -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
      -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" >/dev/null 2>&1
    return $?
  fi
  mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
    -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1" >/dev/null 2>&1
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
    exit 1
  fi
  sleep 1
done
if [ ! -x /app/mudroot/myst ]; then
  echo "[consumer] ERROR: /app/mudroot/myst not found. Run: ./docker-run.sh run --rm consumer ./build.sh sirio-docker"
  exit 1
fi
if [ ! -f /app/mudroot/lib/myst.mob ]; then
  echo "[consumer] ERROR: mudroot/lib/myst.mob missing."
  exit 1
fi
export MYSQL_HOST MYSQL_PORT MYSQL_USER MYSQL_PASSWORD MYSQL_DB="${MYSQL_DB:-nebbie}"
cd /app
echo "[consumer] starting myst -P ${SERVER_PORT} -d ${DATA_DIR}"
exec /app/mudroot/myst -P "${SERVER_PORT}" -d "${DATA_DIR}" -v 4
EOF
chmod +x scripts/docker-entrypoint-consumer.sh

cat > Confs/sirio-docker.conf <<'EOF'
MYSQL_USER="root"
MYSQL_PASSWORD="secret"
MYSQL_HOST="mysql"
MYSQL_DB="nebbie"
MYSQL_PORT=33306
SERVER_PORT=4003
EOF

if [ ! -f docker-compose.yml ]; then
  echo "ERROR: docker-compose.yml not found in $ROOT"
  exit 1
fi

cp docker-compose.yml "docker-compose.yml.bak.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("docker-compose.yml")
text = p.read_text(encoding="utf-8")

# entrypoint consumer
text = re.sub(
    r'entrypoint:\s*\["/usr/local/bin/docker-entrypoint\.sh"\]',
    'entrypoint: ["/bin/bash", "/app/scripts/docker-entrypoint-consumer.sh"]',
    text,
)
text = re.sub(
    r'entrypoint:\s*\["/bin/bash",\s*"/app/scripts/docker-entrypoint-consumer\.sh"\]',
    'entrypoint: ["/bin/bash", "/app/scripts/docker-entrypoint-consumer.sh"]',
    text,
)

# rimuovi tty sul consumer (log vuoti in -d)
text = re.sub(r'\n        tty: true\n', '\n', text)

# SERVER_PORT da env
text = text.replace(
    "- SERVER_PORT=4000\n",
    "- SERVER_PORT=${SERVER_PORT:-4000}\n",
)

# healthcheck mysql se assente
if "healthcheck:" not in text.split("consumer:")[0]:
    text = text.replace(
        'command: ["mysqld", "--port=33306"]\n',
        'command: ["mysqld", "--port=33306"]\n'
        '        healthcheck:\n'
        '            test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-P", "33306", "-uroot", "-psecret"]\n'
        '            interval: 5s\n'
        '            timeout: 5s\n'
        '            retries: 30\n'
        '            start_period: 30s\n',
        1,
    )

# depends_on consumer -> healthy mysql
text = re.sub(
    r'(    consumer:.*?        depends_on:\n)\s+- mysql\n',
    r'\1            mysql:\n                condition: service_healthy\n',
    text,
    count=1,
    flags=re.S,
)

p.write_text(text, encoding="utf-8")
print("Updated docker-compose.yml")
PY

echo ""
echo "OK. Prossimi passi:"
echo "  ./docker-run.sh down"
echo "  ./docker-run.sh run --rm consumer ./build.sh sirio-docker"
echo "  SERVER_PORT=4003 ./docker-run.sh up -d"
echo "  docker logs -f server-consumer-1"
echo "  telnet localhost 4003"
