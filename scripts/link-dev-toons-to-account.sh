#!/bin/bash
# Associa i PG di sviluppo Alar e Taratuffo all'account wizmorgan@gmail.com.
#
# Default: aggiorna solo toon con owner_id=0 o già legati allo stesso account.
# Con FORCE_LINK=1 (o --force): riassegna anche se il PG appartiene a un altro account.
set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_DB="${MYSQL_DB:-nebbie}"
DEV_EMAIL="${DEV_ACCOUNT_EMAIL:-wizmorgan@gmail.com}"
TOON_NAMES="${DEV_TOON_NAMES:-Alar Taratuffo}"
FORCE_LINK="${FORCE_LINK:-0}"

for arg in "$@"; do
	case "$arg" in
		--force) FORCE_LINK=1 ;;
		-h|--help)
			echo "Usage: $0 [--force]"
			echo "  --force   riassegna anche PG già legati ad altri account"
			exit 0
			;;
	esac
done

mysql_q() {
	mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
		-u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "$1" "$MYSQL_DB"
}

echo "==> Collego PG [${TOON_NAMES}] a ${DEV_EMAIL} (force=${FORCE_LINK})"

USER_ID="$(mysql_q "SELECT id FROM user WHERE email='${DEV_EMAIL}' LIMIT 1;" || true)"
if [ -z "$USER_ID" ]; then
	echo "==> Account ${DEV_EMAIL} assente: creare l'account via login/registrazione, poi rilanciare."
	exit 0
fi

for name in $TOON_NAMES; do
	TOON_ID="$(mysql_q "SELECT id FROM toon WHERE LOWER(name)=LOWER('${name}') LIMIT 1;" || true)"
	if [ -z "$TOON_ID" ]; then
		echo "==> Skip: toon '${name}' non trovato in DB"
		continue
	fi

	CURRENT_OWNER="$(mysql_q "SELECT owner_id FROM toon WHERE id=${TOON_ID} LIMIT 1;" || true)"
	CURRENT_EMAIL="$(mysql_q "SELECT email FROM user WHERE id=${CURRENT_OWNER} LIMIT 1;" || true)"

	if [ "${CURRENT_OWNER}" = "${USER_ID}" ]; then
		echo "==> ${name} (id=${TOON_ID}) già collegato a ${DEV_EMAIL}"
		continue
	fi

	if [ -n "${CURRENT_OWNER}" ] && [ "${CURRENT_OWNER}" != "0" ] && [ "${FORCE_LINK}" != "1" ]; then
		echo "==> Skip ${name} (id=${TOON_ID}): owner_id=${CURRENT_OWNER} (${CURRENT_EMAIL:-sconosciuto})"
		echo "    Usa FORCE_LINK=1 $0 oppure $0 --force per riassegnare."
		continue
	fi

	if [ "${FORCE_LINK}" = "1" ] && [ -n "${CURRENT_OWNER}" ] && [ "${CURRENT_OWNER}" != "0" ] && [ "${CURRENT_OWNER}" != "${USER_ID}" ]; then
		echo "==> Riassegno ${name} da owner_id=${CURRENT_OWNER} (${CURRENT_EMAIL:-?}) a ${USER_ID} (${DEV_EMAIL})"
	fi

	AFFECTED="$(mysql_q "UPDATE toon SET owner_id=${USER_ID} WHERE id=${TOON_ID}; SELECT ROW_COUNT();" || true)"
	if [ "${AFFECTED}" = "1" ] || [ "${AFFECTED}" = "0" ]; then
		# ROW_COUNT() after UPDATE: 1 row matched/changed, 0 if already same value
		NEW_OWNER="$(mysql_q "SELECT owner_id FROM toon WHERE id=${TOON_ID} LIMIT 1;" || true)"
		if [ "${NEW_OWNER}" = "${USER_ID}" ]; then
			echo "==> ${name} (id=${TOON_ID}) -> owner_id=${USER_ID} (${DEV_EMAIL})"
		else
			echo "==> ERRORE: ${name} (id=${TOON_ID}) non aggiornato (owner_id=${NEW_OWNER})"
		fi
	else
		echo "==> ERRORE: update ${name} (id=${TOON_ID}) fallito"
	fi
done

echo "==> Verifica:"
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
	-u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e \
	"SELECT t.name, t.owner_id, u.email FROM toon t LEFT JOIN user u ON u.id=t.owner_id WHERE LOWER(t.name) IN ('alar','taratuffo');" \
	"$MYSQL_DB"
