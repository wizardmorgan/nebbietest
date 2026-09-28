#!/bin/bash
# Dev/test: collega Sirio all'account wizmorgan@gmail.com e opzionalmente lo porta a livello 60.
#
# Non modifica il codice di login del MUD: agisce solo su MySQL.
# Default: aggiorna solo toon con owner_id=0 o già legati allo stesso account.
# Con --force: riassegna anche se il PG appartiene a un altro account.
# Con --boost: imposta livello 60 su toon + tabelle character_* (se già migrate).
set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_DB="${MYSQL_DB:-nebbie}"
DEV_EMAIL="${DEV_ACCOUNT_EMAIL:-wizmorgan@gmail.com}"
TOON_NAMES="${DEV_TOON_NAMES:-Sirio}"
TARGET_LEVEL="${DEV_TOON_LEVEL:-60}"
FORCE_LINK="${FORCE_LINK:-0}"
BOOST_LEVEL="${DEV_BOOST_LEVEL:-0}"

for arg in "$@"; do
	case "$arg" in
		--force) FORCE_LINK=1 ;;
		--boost) BOOST_LEVEL=1 ;;
		-h|--help)
			echo "Usage: $0 [--force] [--boost]"
			echo "  --force   riassegna anche PG già legati ad altri account"
			echo "  --boost   imposta livello ${TARGET_LEVEL} su Sirio (solo tabelle PG, non user)"
			exit 0
			;;
	esac
done

mysql_q() {
	mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
		-u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "$1" "$MYSQL_DB"
}

boost_toon_level() {
	local toon_id="$1"
	local name="$2"
	mysql_q "UPDATE toon SET level=${TARGET_LEVEL} WHERE id=${toon_id};"
	if mysql_q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DB}' AND table_name='character_core';" | grep -q '^1$'; then
		local has_core
		has_core="$(mysql_q "SELECT COUNT(*) FROM character_core WHERE toon_id=${toon_id};" || true)"
		if [ "${has_core}" = "0" ]; then
			echo "==> ${name}: nessuna riga character_core (fai un login una volta, poi rilancia con --boost)"
			return 0
		fi
		for idx in $(seq 0 10); do
			mysql_q "INSERT INTO character_classes (toon_id, class_index, level) VALUES (${toon_id}, ${idx}, ${TARGET_LEVEL}) ON DUPLICATE KEY UPDATE level=${TARGET_LEVEL};"
		done
		mysql_q "UPDATE character_stats SET exp=30000000, true_exp=0 WHERE toon_id=${toon_id};"
		echo "==> ${name} (id=${toon_id}) portato a livello ${TARGET_LEVEL} (toon + classi + exp)"
	else
		echo "==> ${name}: schema character_* assente, aggiornato solo toon.level"
	fi
}

echo "==> Collego PG [${TOON_NAMES}] a ${DEV_EMAIL} (force=${FORCE_LINK}, boost=${BOOST_LEVEL})"

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
		if [ "${BOOST_LEVEL}" = "1" ]; then
			boost_toon_level "${TOON_ID}" "${name}"
		fi
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

	mysql_q "UPDATE toon SET owner_id=${USER_ID} WHERE id=${TOON_ID};"
	NEW_OWNER="$(mysql_q "SELECT owner_id FROM toon WHERE id=${TOON_ID} LIMIT 1;" || true)"
	if [ "${NEW_OWNER}" = "${USER_ID}" ]; then
		echo "==> ${name} (id=${TOON_ID}) -> owner_id=${USER_ID} (${DEV_EMAIL})"
		if [ "${BOOST_LEVEL}" = "1" ]; then
			boost_toon_level "${TOON_ID}" "${name}"
		fi
	else
		echo "==> ERRORE: ${name} (id=${TOON_ID}) non aggiornato (owner_id=${NEW_OWNER})"
	fi
done

echo "==> Verifica:"
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
	-u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e \
	"SELECT t.name, t.level, t.owner_id, u.email FROM toon t LEFT JOIN user u ON u.id=t.owner_id WHERE LOWER(t.name) IN ('sirio');" \
	"$MYSQL_DB"
