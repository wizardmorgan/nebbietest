#!/bin/bash
# Dev stack Docker (mysql + adminer + mudcompiler + edit-portal) e myst su porta devel.
# Uso:
#   ./scripts/mud-dev.sh status           # analisi + cosa fare
#   ./scripts/mud-dev.sh start            # mysql + mudcompiler + myst + edit-portal
#   ./scripts/mud-dev.sh start-mud        # solo myst (avvia mysql/container se serve)
#   ./scripts/mud-dev.sh start-edit       # solo edit-portal (mysql se serve)
#   ./scripts/mud-dev.sh start-stack      # mysql + shell interattiva mudcompiler
#   ./scripts/mud-dev.sh stop-mud         # termina myst
#   ./scripts/mud-dev.sh stop-edit        # ferma edit-portal
#   ./scripts/mud-dev.sh stop-all         # ferma tutto (DB in mysql_data/ resta)
#
# Mac:  cd ~/Documents/GitHub/Server && ./scripts/mud-dev.sh start
# NUC:  cd ~/NebbieArcane/Server        && ./scripts/mud-dev.sh start
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENVIRONMENT="${ENVIRONMENT:-devel}"
MUD_PORT="${MUD_PORT:-4002}"
MUD_DATA_DIR="${MUD_DATA_DIR:-lib}"
EDIT_API_PORT="${EDIT_API_PORT:-8090}"
EDIT_API_SECRET="${EDIT_API_SECRET:-nebbie-edit-dev-secret}"
EDIT_WEB_PORT="${EDIT_WEB_PORT:-3080}"

# shellcheck source=scripts/load-mysql-conf.sh
source "${ROOT}/scripts/load-mysql-conf.sh"

if docker compose version >/dev/null 2>&1; then
	COMPOSE='docker compose'
elif command -v docker-compose >/dev/null 2>&1; then
	COMPOSE='docker-compose'
else
	echo "ERRORE: né 'docker compose' né 'docker-compose' trovati." >&2
	exit 1
fi

compose() {
	$COMPOSE "$@"
}

load_mysql_conf

service_running() {
	local svc="$1"
	compose ps 2>/dev/null | grep -i "$svc" | grep -qiE 'up|running'
}

find_mudcompiler_container() {
	local name
	name="$(docker ps --filter 'name=^mudcompiler$' --format '{{.Names}}' 2>/dev/null | head -1)"
	if [ -n "$name" ]; then
		echo "$name"
		return 0
	fi
	name="$(docker ps --filter 'ancestor=nebbiearcane/mudcompiler:latest' --format '{{.Names}}' 2>/dev/null | head -1)"
	if [ -n "$name" ]; then
		echo "$name"
		return 0
	fi
	return 1
}

find_mudcompiler_stopped() {
	docker ps -a --filter 'name=^mudcompiler$' --format '{{.Names}} {{.Status}}' 2>/dev/null | head -1
}

mysql_ping() {
	compose exec -T mysql mysqladmin -h 127.0.0.1 -P 33306 -uroot -psecret ping >/dev/null 2>&1
}

mysql_query() {
	compose exec -T mysql mysql -h 127.0.0.1 -P 33306 -uroot -psecret -N "$MYSQL_DB" -e "$1" 2>/dev/null
}

port_open() {
	if command -v nc >/dev/null 2>&1; then
		nc -z localhost "$1" 2>/dev/null
		return $?
	fi
	return 1
}

myst_pgrep_line() {
	local c="$1"
	docker exec "$c" bash -c 'ps -o pid=,stat=,args= -C myst 2>/dev/null || true'
}

myst_is_alive() {
	local c="$1"
	docker exec "$c" bash -c '
		for pid in $(pgrep -x myst 2>/dev/null); do
			stat=$(ps -o stat= -p "$pid" 2>/dev/null | tr -d " ")
			case "$stat" in
			Z*|z*) continue ;;
			*) exit 0 ;;
			esac
		done
		exit 1
	'
}

myst_has_zombie() {
	local c="$1"
	docker exec "$c" bash -c '
		for pid in $(pgrep -x myst 2>/dev/null); do
			stat=$(ps -o stat= -p "$pid" 2>/dev/null | tr -d " ")
			case "$stat" in
			Z*|z*) exit 0 ;;
			esac
		done
		exit 1
	'
}

myst_running() {
	local c="$1"
	myst_is_alive "$c"
}

force_cleanup_myst() {
	local mudc="$1"
	docker exec "$mudc" pkill -x myst 2>/dev/null || true
	sleep 1
	docker exec "$mudc" pkill -9 -x myst 2>/dev/null || true
	sleep 1
	if myst_has_zombie "$mudc" || myst_is_alive "$mudc"; then
		echo "Zombie/residuo myst in $mudc: restart container..."
		docker restart "$mudc" >/dev/null
		sleep 3
	fi
}

cleanup_orphan_mudcompiler_runs() {
	local ids
	ids="$(docker ps -aq --filter 'name=server-mudcompiler-run' 2>/dev/null || true)"
	if [ -n "$ids" ]; then
		echo "Rimozione container orphan server-mudcompiler-run-* (liberano porte 4000-4002)..."
		docker rm -f $ids 2>/dev/null || true
	fi
}

print_header() {
	echo ""
	echo "=== $1 ==="
}

print_ok() {
	echo "  OK: $1"
}

print_warn() {
	echo "  !! $1"
}

print_do() {
	echo "  -> $1"
}

ensure_mysql_stack() {
	if ! service_running mysql || ! service_running adminer; then
		echo "Avvio mysql e adminer..."
		compose up -d mysql adminer
	fi
	echo "Attesa MySQL..."
	for _ in $(seq 1 45); do
		if mysql_ping; then
			echo "MySQL ok."
			return 0
		fi
		sleep 1
	done
	echo "ERRORE: MySQL non risponde dopo 45s" >&2
	return 1
}

ensure_mudcompiler_container() {
	local mudc stopped_line
	cleanup_orphan_mudcompiler_runs

	if mudc="$(find_mudcompiler_container)"; then
		echo "Container mudcompiler già attivo: $mudc"
		return 0
	fi

	stopped_line="$(find_mudcompiler_stopped)"
	if [ -n "$stopped_line" ]; then
		echo "Riavvio container mudcompiler (era fermo)..."
		docker start mudcompiler
		sleep 2
		if find_mudcompiler_container >/dev/null; then
			echo "Container mudcompiler avviato."
			return 0
		fi
	fi

	echo "Creazione container mudcompiler (--name mudcompiler, porte incl. ${EDIT_API_PORT})..."
	# --name mudcompiler: edit-portal raggiunge myst via http://mudcompiler:8090 sulla rete compose.
	if compose run -d --name mudcompiler --service-ports --entrypoint /bin/bash mudcompiler -c 'sleep infinity'; then
		sleep 2
		if find_mudcompiler_container >/dev/null; then
			echo "Container mudcompiler creato."
			return 0
		fi
	fi

	echo "ERRORE: impossibile avviare mudcompiler." >&2
	echo "Porte occupate? ss -tlnp | grep -E '400|8090'" >&2
	echo "Prova: ./scripts/mud-dev.sh stop-all && ./scripts/mud-dev.sh start" >&2
	return 1
}

cmd_start_edit() {
	ensure_mysql_stack
	if ! find_mudcompiler_container >/dev/null; then
		print_warn "mudcompiler non attivo — API edit non raggiungibile finché non avvii myst"
	fi
	echo "Avvio edit-portal (web ${EDIT_WEB_PORT})..."
	export EDIT_API_SECRET EDIT_WEB_PORT
	compose up -d --build edit-portal
	echo "Web UI: http://localhost:${EDIT_WEB_PORT}/"
}

cmd_stop_edit() {
	compose stop edit-portal 2>/dev/null || true
	compose rm -f edit-portal 2>/dev/null || true
	echo "edit-portal fermato."
}

cmd_status() {
	local mudc=''
	local mysql_up=0 adminer_up=0 myst_up=0 edit_up=0
	local users=0 has_myst_bin=0

	print_header "Contesto"
	echo "  Repo:       $ROOT"
	echo "  Porta mud:  $MUD_PORT (devel)"
	echo "  Edit API:   ${EDIT_API_PORT} (interno Docker: mudcompiler:${EDIT_API_PORT})"
	echo "  Edit web:   ${EDIT_WEB_PORT}"
	echo "  Compose:    $COMPOSE"

	print_header "Docker Compose"
	if service_running mysql; then
		mysql_up=1
		print_ok "mysql in esecuzione"
	else
		print_warn "mysql non in esecuzione"
		print_do "./scripts/mud-dev.sh start"
	fi
	if service_running adminer; then
		adminer_up=1
		print_ok "adminer in esecuzione (http://localhost:8080)"
	else
		print_warn "adminer non in esecuzione"
		print_do "./scripts/mud-dev.sh start"
	fi
	if service_running edit-portal || docker ps --filter 'name=^nebbie-edit-portal$' --format '{{.Names}}' | grep -q .; then
		edit_up=1
		print_ok "edit-portal in esecuzione (http://localhost:${EDIT_WEB_PORT})"
	else
		print_warn "edit-portal non in esecuzione"
		print_do "./scripts/mud-dev.sh start-edit"
	fi

	print_header "Container mudcompiler"
	if mudc="$(find_mudcompiler_container)"; then
		print_ok "container: $mudc"
		docker ps --filter "name=$mudc" --format '  Ports: {{.Ports}}'
		if myst_running "$mudc"; then
			myst_up=1
			print_ok "myst in esecuzione"
			echo "  $(myst_pgrep_line "$mudc")"
		elif myst_has_zombie "$mudc"; then
			print_warn "myst ZOMBIE/defunct"
			print_do "./scripts/mud-dev.sh stop-mud && ./scripts/mud-dev.sh start-mud"
		else
			print_warn "myst NON in esecuzione"
			print_do "./scripts/mud-dev.sh start-mud"
		fi
		if docker exec "$mudc" test -x "/app/mudroot/myst" 2>/dev/null; then
			has_myst_bin=1
			print_ok "binario /app/mudroot/myst presente"
		else
			print_warn "binario myst assente nel container"
			print_do "docker exec -it $mudc bash -c 'cd /app && ./build.sh devel'"
		fi
	else
		stopped_line="$(find_mudcompiler_stopped)"
		if [ -n "$stopped_line" ]; then
			print_warn "mudcompiler fermo: $stopped_line"
		else
			print_warn "nessun container mudcompiler"
		fi
		print_do "./scripts/mud-dev.sh start-mud"
	fi

	print_header "Edit API (porta ${EDIT_API_PORT} host)"
	if port_open "$EDIT_API_PORT"; then
		print_ok "porta ${EDIT_API_PORT} aperta sull'host"
	else
		print_warn "porta ${EDIT_API_PORT} non raggiungibile sull'host"
		if [ "$myst_up" -eq 1 ]; then
			print_do "myst deve essere compilato con edit_portal (branch feature/edit-portal)"
		fi
	fi

	print_header "MySQL"
	if [ "$mysql_up" -eq 1 ] && mysql_ping; then
		print_ok "mysqladmin ping"
		users="$(mysql_query 'SELECT COUNT(*) FROM user;' || echo 0)"
		if [ "${users:-0}" -gt 0 ] 2>/dev/null; then
			print_ok "tabella user: $users account"
		else
			print_warn "tabella user vuota o DB non importato"
		fi
	else
		print_warn "MySQL non risponde"
		print_do "./scripts/mud-dev.sh start"
	fi

	print_header "Porta $MUD_PORT (host)"
	if port_open "$MUD_PORT"; then
		if [ "$myst_up" -eq 1 ]; then
			print_ok "porta aperta e myst attivo — telnet/Mudlet ok"
		else
			print_warn "porta aperta ma myst NON attivo"
			print_do "./scripts/mud-dev.sh start-mud"
		fi
	else
		print_warn "porta $MUD_PORT non raggiungibile"
		print_do "./scripts/mud-dev.sh start-mud"
	fi

	print_header "Riepilogo"
	if [ "$mysql_up" -eq 1 ] && [ "$myst_up" -eq 1 ] && port_open "$MUD_PORT"; then
		echo "  MUD ok. telnet localhost $MUD_PORT"
		if [ "$edit_up" -eq 1 ]; then
			echo "  Edit web: http://localhost:${EDIT_WEB_PORT}/"
		fi
		return 0
	fi

	echo "  Comando rapido: ./scripts/mud-dev.sh start"
	return 1
}

cmd_start_mud() {
	ensure_mysql_stack
	ensure_mudcompiler_container

	local mudc
	mudc="$(find_mudcompiler_container)"

	if myst_is_alive "$mudc"; then
		echo "myst già in esecuzione in $mudc:"
		myst_pgrep_line "$mudc"
		return 0
	fi
	if myst_has_zombie "$mudc"; then
		echo "myst defunct/zombie — pulizia prima del riavvio..."
		force_cleanup_myst "$mudc"
		mudc="$(find_mudcompiler_container)"
	fi

	docker exec "$mudc" bash -c "
		set -e
		cd /app
		ln -sfn ../pages mudroot/pages
		cp -n myst.* mudroot/lib/ 2>/dev/null || true
		if [ ! -f mudroot/lib/edit_system.json ] && [ -f Confs/edit_system.default.json ]; then
			cp Confs/edit_system.default.json mudroot/lib/edit_system.json
		fi
		cd /app/mudroot
		export EDIT_API_PORT='${EDIT_API_PORT}'
		export EDIT_API_SECRET='${EDIT_API_SECRET}'
		./myst -D -P $MUD_PORT -d $MUD_DATA_DIR
	"
	sleep 2
	if myst_is_alive "$mudc"; then
		echo "myst avviato (edit API ${EDIT_API_PORT} se compilato con edit_portal):"
		myst_pgrep_line "$mudc"
		echo "telnet localhost $MUD_PORT"
	else
		echo "ERRORE: myst non partito. Log:" >&2
		docker exec "$mudc" tail -20 /app/mudroot/errors.log 2>/dev/null || true
		docker exec "$mudc" tail -30 /app/mudroot/alarmud.log 2>/dev/null || true
		exit 1
	fi
}

cmd_start() {
	cmd_start_mud
	cmd_start_edit
	cmd_status
}

cmd_start_stack() {
	ensure_mysql_stack
	echo "Shell interattiva mudcompiler (exit per uscire):"
	exec compose run --rm -it --service-ports --entrypoint /bin/bash mudcompiler
}

cmd_stop_mud() {
	local mudc
	if mudc="$(find_mudcompiler_container)"; then
		force_cleanup_myst "$mudc"
		echo "myst terminato (o container riavviato se era zombie)."
	else
		echo "Nessun container mudcompiler attivo."
	fi
}

cmd_logs() {
	local mudc lines="${1:-40}"
	if ! mudc="$(find_mudcompiler_container)"; then
		echo "Nessun container mudcompiler." >&2
		return 1
	fi
	echo "=== errors.log (tail $lines) ==="
	docker exec "$mudc" tail -n "$lines" /app/mudroot/errors.log 2>/dev/null || echo "(assente)"
	echo "=== alarmud.log (tail $lines) ==="
	docker exec "$mudc" tail -n "$lines" /app/mudroot/alarmud.log 2>/dev/null || echo "(assente)"
	echo "=== edit_portal ==="
	docker exec "$mudc" grep edit_portal /app/mudroot/alarmud.log 2>/dev/null | tail -10 || true
	echo "=== myst ps ==="
	myst_pgrep_line "$mudc"
}

cmd_stop_all() {
	cmd_stop_mud
	cmd_stop_edit
	docker rm -f mudcompiler 2>/dev/null || true
	cleanup_orphan_mudcompiler_runs
	local ids
	ids="$(docker ps -aq --filter 'ancestor=nebbiearcane/mudcompiler:latest' 2>/dev/null || true)"
	if [ -n "$ids" ]; then
		docker rm -f $ids 2>/dev/null || true
	fi
	compose down --remove-orphans 2>/dev/null || compose stop mysql adminer 2>/dev/null || true
	echo "Stack fermato (mysql_data/ conservato)."
}

usage() {
	cat <<EOF
Uso: ./scripts/mud-dev.sh <comando>

  status        Analisi e suggerimenti (default)
  start         Avvia mysql + mudcompiler + myst + edit-portal
  start-mud     Avvia myst (mysql/container se necessario)
  start-edit    Avvia solo edit-portal (build se serve)
  start-stack   mysql + shell interattiva nel container
  stop-mud      Termina myst
  stop-edit     Ferma edit-portal
  logs [n]      Tail log myst nel container
  stop-all      Ferma myst, mudcompiler, edit-portal, mysql, adminer

Variabili: MUD_PORT=4002  EDIT_API_PORT=8090  EDIT_WEB_PORT=3080
           EDIT_API_SECRET=...  ENVIRONMENT=devel  MUD_DATA_DIR=lib

edit-portal richiede myst con edit_portal (branch feature/edit-portal) e container --name mudcompiler.
EOF
}

main() {
	local cmd="${1:-status}"
	case "$cmd" in
	status) cmd_status ;;
	start) cmd_start ;;
	start-mud) cmd_start_mud ;;
	start-edit) cmd_start_edit ;;
	start-stack) cmd_start_stack ;;
	stop-mud) cmd_stop_mud ;;
	stop-edit) cmd_stop_edit ;;
	logs) cmd_logs "${2:-40}" ;;
	stop-all) cmd_stop_all ;;
	-h | --help | help) usage ;;
	*)
		echo "Comando sconosciuto: $cmd" >&2
		usage >&2
		exit 1
		;;
	esac
}

main "$@"
