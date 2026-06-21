#!/usr/bin/env bash
# associate-pg-account.sh
#
# Controlla se un PG esiste nel DB nebbie e nei file del mud (lib/players, lib/rent),
# mostra lo stato e permette di collegarlo a un account (user.email → toon.owner_id).
# Opzionalmente forza il livello del PG su MySQL (toon + character_* se migrate).
#
# Uso interattivo:
#   ./scripts/associate-pg-account.sh
#   ./scripts/associate-pg-account.sh Sirio
#
# Uso non interattivo:
#   ./scripts/associate-pg-account.sh Sirio --account wizmorgan@gmail.com --yes
#   ./scripts/associate-pg-account.sh Sirio -a wizmorgan@gmail.com --force --yes
#   ./scripts/associate-pg-account.sh Sirio --boost --yes
#   ./scripts/associate-pg-account.sh Sirio --boost --level 60 --yes
#
# Variabili d'ambiente (come gli altri script):
#   MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DB
#   MUD_LIB  — directory lib del mud (default: auto)
#   DEV_TOON_LEVEL — livello usato da --boost (default: 60)

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_DB="${MYSQL_DB:-nebbie}"

PG_NAME=""
ACCOUNT_SPEC=""
FORCE_LINK=0
ASSUME_YES=0
DRY_RUN=0
BOOST_PG=0
TARGET_LEVEL="${DEV_TOON_LEVEL:-60}"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'ATTENZIONE: %s\n' "$*" >&2; }
die() { printf 'ERRORE: %s\n' "$*" >&2; exit 1; }

usage() {
	cat <<'EOF'
Uso: associate-pg-account.sh [nome_pg] [opzioni]

Opzioni:
  -a, --account <email|id>   Account destinazione (email o id numerico user)
  -f, --force                Riassegna anche se owner_id punta ad altro account
  -b, --boost                Forza il livello del PG su MySQL (default: 60)
  --level <n>                Livello da impostare con --boost (default: 60)
  -y, --yes                  Salta la conferma finale
  -n, --dry-run              Mostra solo controlli, nessun UPDATE
  -h, --help                 Questo messaggio

Esempi:
  ./scripts/associate-pg-account.sh Sirio
  ./scripts/associate-pg-account.sh Sirio -a wizmorgan@gmail.com
  ./scripts/associate-pg-account.sh Sirio -a 42 --force -y
  ./scripts/associate-pg-account.sh Sirio --boost -y
  ./scripts/associate-pg-account.sh Sirio --boost --level 60 -y

Con --boost aggiorna toon.level e, se presenti, character_classes e character_stats.
Non modifica user.level dell'account. Dopo il boost, un PG già in gioco può
mostrare il livello vecchio finché non si rilogga (il MUD ricarica da MySQL).

File controllati (sotto MUD_LIB, nome in minuscolo):
  players/<nome>.dat
  players/<nome>.dead
  rent/<nome>
  rent/<nome>.aux
EOF
}

detect_mud_lib() {
	if [[ -n "${MUD_LIB:-}" ]]; then
		printf '%s' "$MUD_LIB"
		return
	fi
	local candidates=(
		"$(pwd)/lib"
		"$(pwd)"
		"/vagrant/mudroot/lib"
		"/home/nebbie/Server/mudroot/lib"
		"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/mudroot/lib"
	)
	local c
	for c in "${candidates[@]}"; do
		if [[ -d "${c}/players" ]]; then
			printf '%s' "$c"
			return
		fi
	done
	printf '%s' "./mudroot/lib"
}

mysql_q() {
	mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
		-u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -B -e "$1" "$MYSQL_DB" 2>/dev/null
}

mysql_table() {
	mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP \
		-u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$1" "$MYSQL_DB" 2>/dev/null
}

normalize_pg_name() {
	local n="$1"
	if [[ ! "$n" =~ ^[A-Za-z]{1,15}$ ]]; then
		die "Nome PG non valido: '${n}' (solo lettere, max 15)"
	fi
	printf '%s' "$n"
}

pg_file_key() {
	printf '%s' "$(echo "$1" | tr '[:upper:]' '[:lower:]')"
}

read_internal_dat_name() {
	local dat="$1"
	if [[ ! -r "$dat" ]]; then
		return 1
	fi
	if command -v python3 >/dev/null 2>&1; then
		python3 - "$dat" <<'PY' 2>/dev/null || true
import sys
path = sys.argv[1]
ABS_MAX_CLASS, MAX_TOUNGE = 20, 3
MAX_SKILLS, MAX_AFFECT = 350, 40
CHAR_POINT_SIZE = 46
CHAR_SKILL_SIZE = 4
AFFECTED_U_SIZE = 20
NAME_OFF = (
    4 + 1 + ABS_MAX_CLASS + 4 + 4 + 4 + 4 + 4
    + 80 + 255 + 2 + 240 + MAX_TOUNGE + 4 + 2 + 9 + CHAR_POINT_SIZE
    + CHAR_SKILL_SIZE * MAX_SKILLS + AFFECTED_U_SIZE * MAX_AFFECT
    + 1 + 4 + 4 + 4 + 4 + 4
)
with open(path, "rb") as f:
    data = f.read()
if len(data) < NAME_OFF + 20:
    raise SystemExit(0)
name = data[NAME_OFF:NAME_OFF + 20].split(b"\0", 1)[0].decode("latin-1", "replace").strip()
if name:
    print(name)
PY
	fi
}

check_mysql() {
	mysql_q "SELECT 1;" >/dev/null || die "MySQL non raggiungibile (${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB})"
}

check_files() {
	local key="$1"
	local lib="$2"
	local -a paths
	local i

	paths=(
		"${lib}/players/${key}.dat"
		"${lib}/players/${key}.dead"
		"${lib}/rent/${key}"
		"${lib}/rent/${key}.aux"
	)

	FILE_PLAYERS_DAT="no"
	FILE_PLAYERS_DEAD="no"
	FILE_RENT="no"
	FILE_RENT_AUX="no"
	FILE_INTERNAL_NAME=""

	for i in "${!paths[@]}"; do
		if [[ -f "${paths[$i]}" ]]; then
			case "$i" in
				0) FILE_PLAYERS_DAT="sì ($(stat -c '%s bytes' "${paths[$i]}" 2>/dev/null || stat -f '%z bytes' "${paths[$i]}"))" ;;
				1) FILE_PLAYERS_DEAD="sì" ;;
				2) FILE_RENT="sì" ;;
				3) FILE_RENT_AUX="sì" ;;
			esac
		fi
	done

	if [[ -f "${lib}/players/${key}.dat" ]]; then
		FILE_INTERNAL_NAME="$(read_internal_dat_name "${lib}/players/${key}.dat" || true)"
	fi
}

check_db() {
	local name="$1"

	DB_TOON_ID=""
	DB_TOON_NAME=""
	DB_TOON_LEVEL=""
	DB_OWNER_ID=""
	DB_OWNER_EMAIL=""
	DB_MIGRATED=""
	DB_SCHEMA_VER=""
	DB_LEGACY_EMAIL=""
	DB_CHARACTER_CORE="0"

	local row
	row="$(mysql_q "SELECT t.id, t.name, t.level, t.owner_id, IFNULL(u.email,''), IFNULL(t.migrated_at,''), IFNULL(t.schema_version,0) FROM toon t LEFT JOIN user u ON u.id=t.owner_id WHERE LOWER(t.name)=LOWER('${name//\'/\\\'}') LIMIT 1;" || true)"
	if [[ -n "$row" ]]; then
		IFS=$'\t' read -r DB_TOON_ID DB_TOON_NAME DB_TOON_LEVEL DB_OWNER_ID DB_OWNER_EMAIL DB_MIGRATED DB_SCHEMA_VER <<<"$row"
	fi

	if mysql_q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DB}' AND table_name='legacy';" | grep -q '^1$'; then
		DB_LEGACY_EMAIL="$(mysql_q "SELECT IFNULL(email1,'') FROM legacy WHERE LOWER(name)=LOWER('${name//\'/\\\'}') LIMIT 1;" || true)"
	fi

	if [[ -n "$DB_TOON_ID" ]] && mysql_q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DB}' AND table_name='character_core';" | grep -q '^1$'; then
		DB_CHARACTER_CORE="$(mysql_q "SELECT COUNT(*) FROM character_core WHERE toon_id=${DB_TOON_ID};" || true)"
	fi
}

resolve_account() {
	local spec="$1"
	local row

	if [[ "$spec" =~ ^[0-9]+$ ]]; then
		row="$(mysql_q "SELECT id, email, IFNULL(nickname,''), level FROM user WHERE id=${spec} LIMIT 1;" || true)"
	else
		row="$(mysql_q "SELECT id, email, IFNULL(nickname,''), level FROM user WHERE LOWER(email)=LOWER('${spec//\'/\\\'}') LIMIT 1;" || true)"
	fi

	if [[ -z "$row" ]]; then
		return 1
	fi

	IFS=$'\t' read -r TARGET_USER_ID TARGET_USER_EMAIL TARGET_USER_NICK TARGET_USER_LEVEL <<<"$row"
	return 0
}

print_report() {
	local name="$1"
	local lib="$2"
	local key
	key="$(pg_file_key "$name")"

	echo ""
	echo "════════════════════════════════════════════════════════════"
	echo " PG: ${name}   (file key: ${key})"
	echo " MUD_LIB: ${lib}"
	echo " MySQL: ${MYSQL_USER}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}"
	echo "════════════════════════════════════════════════════════════"
	echo ""
	echo "── Database ──"
	if [[ -n "$DB_TOON_ID" ]]; then
		echo "  toon.id .............. ${DB_TOON_ID}"
		echo "  toon.name ............ ${DB_TOON_NAME}"
		echo "  toon.level ........... ${DB_TOON_LEVEL}"
		if [[ -z "$DB_OWNER_ID" || "$DB_OWNER_ID" == "0" ]]; then
			echo "  toon.owner_id ........ 0 (non collegato)"
		else
			echo "  toon.owner_id ........ ${DB_OWNER_ID} (${DB_OWNER_EMAIL:-email sconosciuta})"
		fi
		echo "  toon.migrated_at ..... ${DB_MIGRATED:-—}"
		echo "  toon.schema_version .. ${DB_SCHEMA_VER}"
		echo "  character_core ....... ${DB_CHARACTER_CORE} riga/e"
	else
		echo "  toon ................. ASSENTE nel DB"
	fi
	if [[ -n "$DB_LEGACY_EMAIL" ]]; then
		echo "  legacy.email1 ........ ${DB_LEGACY_EMAIL}"
	fi
	echo ""
	echo "── File mud ──"
	echo "  players/${key}.dat ... ${FILE_PLAYERS_DAT:-no}"
	if [[ -n "$FILE_INTERNAL_NAME" && "$FILE_INTERNAL_NAME" != "$name" ]]; then
		warn "Nome interno nel .dat: '${FILE_INTERNAL_NAME}' (diverso da '${name}')"
	fi
	echo "  players/${key}.dead .. ${FILE_PLAYERS_DEAD:-no}"
	echo "  rent/${key} .......... ${FILE_RENT:-no}"
	echo "  rent/${key}.aux ...... ${FILE_RENT_AUX:-no}"
	echo ""

	if [[ -z "$DB_TOON_ID" && "${FILE_PLAYERS_DAT:-no}" == no ]]; then
		warn "PG assente sia dal DB sia dai file players/*.dat"
	elif [[ -z "$DB_TOON_ID" && "${FILE_PLAYERS_DAT:-no}" != no ]]; then
		warn "File .dat presente ma riga toon assente: al primo login il MUD la creerà (getFromDb)."
	fi
}

prompt_account() {
	local input
	while true; do
		read -r -p "Email o id account destinazione: " input
		input="$(echo "$input" | xargs)"
		[[ -n "$input" ]] || continue
		if resolve_account "$input"; then
			return 0
		fi
		warn "Account non trovato: ${input}"
	done
}

confirm_link() {
	local name="$1"
	echo ""
	echo "Collegamento proposto:"
	echo "  PG '${name}' (toon.id=${DB_TOON_ID})"
	echo "    → account id=${TARGET_USER_ID} (${TARGET_USER_EMAIL})"
	if [[ -n "$TARGET_USER_NICK" ]]; then
		echo "    nickname: ${TARGET_USER_NICK}"
	fi
	if [[ "$ASSUME_YES" == "1" ]]; then
		return 0
	fi
	local ans
	read -r -p "Confermi? [y/N] " ans
	[[ "${ans:-}" =~ ^[yY]$ ]]
}

confirm_boost() {
	local name="$1"
	echo ""
	echo "Boost livello proposto:"
	echo "  PG '${name}' (toon.id=${DB_TOON_ID})"
	echo "    livello attuale: ${DB_TOON_LEVEL:-?}"
	echo "    nuovo livello .. ${TARGET_LEVEL}"
	if [[ "$ASSUME_YES" == "1" ]]; then
		return 0
	fi
	local ans
	read -r -p "Confermi? [y/N] " ans
	[[ "${ans:-}" =~ ^[yY]$ ]]
}

do_link() {
	local name="$1"
	local sql

	if [[ -z "$DB_TOON_ID" ]]; then
		die "Impossibile collegare: il PG non esiste in tabella toon. Fai un login col nome del personaggio (crea la riga) e rilancia."
	fi

	if [[ "$DB_OWNER_ID" == "$TARGET_USER_ID" ]]; then
		log "Già collegato a ${TARGET_USER_EMAIL} (owner_id=${TARGET_USER_ID})"
		return 0
	fi

	if [[ -n "$DB_OWNER_ID" && "$DB_OWNER_ID" != "0" && "$FORCE_LINK" != "1" ]]; then
		die "PG già assegnato a owner_id=${DB_OWNER_ID} (${DB_OWNER_EMAIL:-?}). Usa --force per riassegnare."
	fi

	sql="UPDATE toon SET owner_id=${TARGET_USER_ID} WHERE id=${DB_TOON_ID};"
	if [[ "$DRY_RUN" == "1" ]]; then
		log "[dry-run] ${sql}"
		return 0
	fi

	mysql_q "$sql" || die "UPDATE fallito"
	local new_owner
	new_owner="$(mysql_q "SELECT owner_id FROM toon WHERE id=${DB_TOON_ID} LIMIT 1;" || true)"
	if [[ "$new_owner" != "$TARGET_USER_ID" ]]; then
		die "Verifica fallita: owner_id=${new_owner}"
	fi
	log "Collegato: ${name} (toon.id=${DB_TOON_ID}) → ${TARGET_USER_EMAIL} (user.id=${TARGET_USER_ID})"
}

# Forza il livello del PG su MySQL (toon + classi/exp se migrate).
# Non tocca user.level dell'account.
boost_toon_level() {
	local toon_id="$1"
	local name="$2"

	if [[ -z "$toon_id" ]]; then
		die "Impossibile boost: toon.id assente"
	fi
	if [[ ! "$TARGET_LEVEL" =~ ^[0-9]+$ ]] || [[ "$TARGET_LEVEL" -lt 1 ]] || [[ "$TARGET_LEVEL" -gt 60 ]]; then
		die "Livello non valido: ${TARGET_LEVEL} (atteso 1-60)"
	fi

	if [[ "$DRY_RUN" == "1" ]]; then
		log "[dry-run] UPDATE toon SET level=${TARGET_LEVEL} WHERE id=${toon_id};"
		if mysql_q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DB}' AND table_name='character_core';" | grep -q '^1$'; then
			log "[dry-run] character_classes / character_stats per toon_id=${toon_id}"
		fi
		return 0
	fi

	mysql_q "UPDATE toon SET level=${TARGET_LEVEL} WHERE id=${toon_id};"

	if mysql_q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DB}' AND table_name='character_core';" | grep -q '^1$'; then
		local has_core
		has_core="$(mysql_q "SELECT COUNT(*) FROM character_core WHERE toon_id=${toon_id};" || true)"
		if [[ "${has_core}" == "0" ]]; then
			warn "${name}: nessuna riga character_core (fai un login una volta, poi rilancia --boost)"
			log "Aggiornato solo toon.level → ${TARGET_LEVEL}"
			return 0
		fi
		local idx
		for idx in $(seq 0 10); do
			mysql_q "INSERT INTO character_classes (toon_id, class_index, level) VALUES (${toon_id}, ${idx}, ${TARGET_LEVEL}) ON DUPLICATE KEY UPDATE level=${TARGET_LEVEL};"
		done
		mysql_q "UPDATE character_stats SET exp=30000000, true_exp=0 WHERE toon_id=${toon_id};"
		log "${name} (id=${toon_id}) portato a livello ${TARGET_LEVEL} (toon + classi + exp)"
	else
		log "${name}: schema character_* assente, aggiornato solo toon.level → ${TARGET_LEVEL}"
	fi

	DB_TOON_LEVEL="${TARGET_LEVEL}"
}

do_boost() {
	local name="$1"

	if [[ -z "$DB_TOON_ID" ]]; then
		die "Impossibile boost: il PG non esiste in tabella toon. Fai un login col nome del personaggio e rilancia."
	fi

	if [[ "$DB_TOON_LEVEL" == "$TARGET_LEVEL" ]]; then
		log "Già a livello ${TARGET_LEVEL} in toon.level"
	fi

	if confirm_boost "$name"; then
		boost_toon_level "$DB_TOON_ID" "$name"
	else
		log "Boost annullato."
		return 1
	fi
}

print_verification() {
	local name="$1"
	echo ""
	log "Verifica:"
	mysql_table "SELECT t.id AS toon_id, t.name, t.level, t.owner_id, u.email AS account_email, t.migrated_at
		FROM toon t LEFT JOIN user u ON u.id=t.owner_id
		WHERE LOWER(t.name)=LOWER('${name//\'/\\\'}');"
	if mysql_q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DB}' AND table_name='character_classes';" | grep -q '^1$'; then
		if [[ -n "$DB_TOON_ID" ]]; then
			mysql_table "SELECT class_index, level FROM character_classes WHERE toon_id=${DB_TOON_ID} ORDER BY class_index;"
		fi
	fi
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				usage
				exit 0
				;;
			-a|--account)
				shift
				ACCOUNT_SPEC="${1:-}"
				[[ -n "$ACCOUNT_SPEC" ]] || die "Manca valore per --account"
				;;
			-f|--force)
				FORCE_LINK=1
				;;
			-b|--boost)
				BOOST_PG=1
				;;
			--level)
				shift
				TARGET_LEVEL="${1:-}"
				[[ -n "$TARGET_LEVEL" ]] || die "Manca valore per --level"
				BOOST_PG=1
				;;
			-y|--yes)
				ASSUME_YES=1
				;;
			-n|--dry-run)
				DRY_RUN=1
				;;
			--*)
				die "Opzione sconosciuta: $1"
				;;
			-*)
				die "Opzione sconosciuta: $1"
				;;
			*)
				if [[ -z "$PG_NAME" ]]; then
					PG_NAME="$1"
				else
					die "Troppi argomenti: $1"
				fi
				;;
		esac
		shift
	done
}

main() {
	parse_args "$@"

	MUD_LIB="$(detect_mud_lib)"

	if [[ -z "$PG_NAME" ]]; then
		read -r -p "Nome personaggio (PG): " PG_NAME
	fi
	PG_NAME="$(normalize_pg_name "$PG_NAME")"

	check_mysql
	check_files "$PG_NAME" "$MUD_LIB"
	check_db "$PG_NAME"
	print_report "$PG_NAME" "$MUD_LIB"

	# Solo boost, senza collegamento account
	if [[ "$BOOST_PG" == "1" && -z "$ACCOUNT_SPEC" ]]; then
		if [[ -z "$DB_TOON_ID" ]]; then
			die "Impossibile boost: riga toon assente per '${PG_NAME}'"
		fi
		do_boost "$PG_NAME"
		print_verification "$PG_NAME"
		exit 0
	fi

	if [[ -z "$ACCOUNT_SPEC" ]]; then
		echo ""
		read -r -p "Vuoi collegare questo PG a un account? [y/N] " link_ans
		if [[ ! "${link_ans:-}" =~ ^[yY]$ ]]; then
			if [[ "$BOOST_PG" == "1" ]]; then
				do_boost "$PG_NAME"
				print_verification "$PG_NAME"
			else
				log "Nessuna modifica."
			fi
			exit 0
		fi
		prompt_account
	else
		resolve_account "$ACCOUNT_SPEC" || die "Account non trovato: ${ACCOUNT_SPEC}"
	fi

	if [[ -z "$DB_TOON_ID" ]]; then
		echo ""
		warn "Senza riga in toon non posso eseguire UPDATE owner_id."
		warn "Avvia il mud e fai login con il nome '${PG_NAME}' (o attendi import), poi rilancia questo script."
		exit 2
	fi

	local linked=0
	if confirm_link "$PG_NAME"; then
		do_link "$PG_NAME"
		linked=1
	else
		log "Collegamento annullato."
	fi

	if [[ "$BOOST_PG" == "1" ]]; then
		do_boost "$PG_NAME" || true
	fi

	if [[ "$linked" == "1" || "$BOOST_PG" == "1" ]]; then
		print_verification "$PG_NAME"
	fi
}

main "$@"
