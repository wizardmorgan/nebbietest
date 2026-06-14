#!/bin/bash
# Associa i PG di sviluppo Alar e Taratuffo all'account wizmorgan@gmail.com.
# Idempotente: aggiorna solo toon con owner_id=0 o già legati allo stesso account.
set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_DB="${MYSQL_DB:-nebbie}"
DEV_EMAIL="${DEV_ACCOUNT_EMAIL:-wizmorgan@gmail.com}"
TOON_NAMES="${DEV_TOON_NAMES:-Alar Taratuffo}"

mysql_q() {
	mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
		-u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "$1" "$MYSQL_DB"
}

echo "==> Collego PG [${TOON_NAMES}] a ${DEV_EMAIL}"

USER_ID="$(mysql_q "SELECT id FROM user WHERE email='${DEV_EMAIL}' LIMIT 1;" || true)"
if [ -z "$USER_ID" ]; then
	echo "==> Account ${DEV_EMAIL} assente: creare l'account via login web/registrazione, poi rilanciare."
	exit 0
fi

for name in $TOON_NAMES; do
	LOWER_NAME="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
	TOON_ID="$(mysql_q "SELECT id FROM toon WHERE LOWER(name)=LOWER('${name}') LIMIT 1;" || true)"
	if [ -z "$TOON_ID" ]; then
		echo "==> Skip: toon '${name}' non trovato in DB"
		continue
	fi
	mysql_q "UPDATE toon SET owner_id=${USER_ID} WHERE id=${TOON_ID} AND (owner_id=0 OR owner_id=${USER_ID});"
	echo "==> ${name} (id=${TOON_ID}) -> owner_id=${USER_ID}"
done

echo "==> Verifica:"
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
	-u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e \
	"SELECT t.name, t.owner_id, u.email FROM toon t LEFT JOIN user u ON u.id=t.owner_id WHERE LOWER(t.name) IN ('alar','taratuffo');" \
	"$MYSQL_DB"
