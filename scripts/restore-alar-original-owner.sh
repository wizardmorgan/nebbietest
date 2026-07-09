#!/bin/bash
# Ripristina Alar (e opzionalmente Taratuffo) al proprietario originale nel DB.
#
# Usato dopo test dev con link-dev-toons-to-account.sh --force che aveva spostato
# i PG su wizmorgan@gmail.com. Default proprietario: giovanni@gargani.it
#
# Opzionale: --cleanup-wizmorgan rimuove duplicati user e resetta nickname/level
# dell'account wizmorgan se alterati dal login di test con Alar.
set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_DB="${MYSQL_DB:-nebbie}"
ORIGINAL_OWNER_EMAIL="${ALAR_ORIGINAL_OWNER_EMAIL:-giovanni@gargani.it}"
TOON_NAMES="${RESTORE_TOON_NAMES:-Alar}"
WIZMORGAN_EMAIL="${WIZMORGAN_ACCOUNT_EMAIL:-wizmorgan@gmail.com}"
CLEANUP_WIZMORGAN="${CLEANUP_WIZMORGAN:-0}"

for arg in "$@"; do
	case "$arg" in
		--cleanup-wizmorgan) CLEANUP_WIZMORGAN=1 ;;
		-h|--help)
			echo "Usage: $0 [--cleanup-wizmorgan]"
			echo "  Ripristina owner_id di Alar (default) su ${ORIGINAL_OWNER_EMAIL}"
			echo "  --cleanup-wizmorgan  dedupe user wizmorgan + reset nickname/level account test"
			exit 0
			;;
	esac
done

mysql_q() {
	mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
		-u"$MYSQL_USER" -p"${MYSQL_PASSWORD}" -N -e "$1" "$MYSQL_DB"
}

echo "==> Ripristino owner PG [${TOON_NAMES}] -> ${ORIGINAL_OWNER_EMAIL}"

OWNER_ID="$(mysql_q "SELECT id FROM user WHERE email='${ORIGINAL_OWNER_EMAIL}' LIMIT 1;" || true)"
if [ -z "$OWNER_ID" ]; then
	echo "ERRORE: account ${ORIGINAL_OWNER_EMAIL} non trovato in user"
	exit 1
fi

for name in $TOON_NAMES; do
	TOON_ID="$(mysql_q "SELECT id FROM toon WHERE LOWER(name)=LOWER('${name}') LIMIT 1;" || true)"
	if [ -z "$TOON_ID" ]; then
		echo "==> Skip: toon '${name}' non trovato"
		continue
	fi
	PREV_OWNER="$(mysql_q "SELECT owner_id FROM toon WHERE id=${TOON_ID} LIMIT 1;" || true)"
	PREV_EMAIL="$(mysql_q "SELECT email FROM user WHERE id=${PREV_OWNER} LIMIT 1;" || true)"
	mysql_q "UPDATE toon SET owner_id=${OWNER_ID} WHERE id=${TOON_ID};"
	echo "==> ${name} (id=${TOON_ID}): owner_id ${PREV_OWNER} (${PREV_EMAIL:-?}) -> ${OWNER_ID} (${ORIGINAL_OWNER_EMAIL})"
done

if [ "${CLEANUP_WIZMORGAN}" = "1" ]; then
	echo "==> Pulizia account test ${WIZMORGAN_EMAIL}"
	DUPES="$(mysql_q "SELECT COUNT(*) FROM user WHERE email='${WIZMORGAN_EMAIL}';" || true)"
	if [ "${DUPES:-0}" -gt 1 ]; then
		mysql_q "DELETE u1 FROM user u1 INNER JOIN user u2 ON u1.email=u2.email AND u1.id>u2.id WHERE u1.email='${WIZMORGAN_EMAIL}';"
		echo "==> Rimossi duplicati user (${DUPES} -> 1)"
	fi
	WIZ_ID="$(mysql_q "SELECT id FROM user WHERE email='${WIZMORGAN_EMAIL}' LIMIT 1;" || true)"
	if [ -n "$WIZ_ID" ]; then
		WIZ_NICK="$(mysql_q "SELECT nickname FROM user WHERE id=${WIZ_ID} LIMIT 1;" || true)"
		WIZ_LEVEL="$(mysql_q "SELECT level FROM user WHERE id=${WIZ_ID} LIMIT 1;" || true)"
		if [ "${WIZ_NICK,,}" = "alar" ]; then
			mysql_q "UPDATE user SET nickname='${WIZMORGAN_EMAIL}' WHERE id=${WIZ_ID};"
			echo "==> user id=${WIZ_ID}: nickname ripristinato a ${WIZMORGAN_EMAIL}"
		fi
		if [ "${WIZ_LEVEL}" = "60" ] && [ "${WIZ_NICK,,}" = "alar" ]; then
			mysql_q "UPDATE user SET level=0 WHERE id=${WIZ_ID};"
			echo "==> user id=${WIZ_ID}: level 60 (sync test Alar) -> 0 (controlla se serve altro valore)"
		fi
	fi
fi

echo "==> Verifica:"
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
	-u"$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e \
	"SELECT t.name, t.level, t.owner_id, u.email AS owner_email FROM toon t LEFT JOIN user u ON u.id=t.owner_id WHERE LOWER(t.name) IN ('alar'); \
	 SELECT id, email, nickname, level FROM user WHERE email IN ('${ORIGINAL_OWNER_EMAIL}','${WIZMORGAN_EMAIL}');" \
	"$MYSQL_DB"
