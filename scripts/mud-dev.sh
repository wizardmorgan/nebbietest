#!/bin/bash
# Dev Docker: mysql/adminer/mudcompiler/myst su NebbieArcane + edit-portal opzionale dal fork.
#
# Due repo (setup nucbuntu consigliato):
#   MUD_ROOT   = ~/NebbieArcane/Server   → git pull origin feature/Razze (upstream, non sporcare)
#   EDIT_REPO  = ~/docker-vms/Server     → git pull mine feature/edit-portal (edit-portal + edit_portal.cpp)
#   Config:    ~/.config/nebbie/mud-dev.env (vedi docs/nebbie-mud-dev.env.example)
#
# Uso:
#   ./scripts/mud-dev.sh status
#   ./scripts/mud-dev.sh start-mud          # solo MUD (sorgente = MUD_APP_ROOT, default MUD_ROOT)
#   ./scripts/mud-dev.sh start-edit         # solo edit-portal (mysql da MUD_ROOT)
#   ./scripts/mud-dev.sh start              # myst + edit-portal (MUD_APP_ROOT=EDIT_REPO in config)
#   ./scripts/mud-dev.sh stop-all
#
# Lo script può stare in EDIT_REPO; non serve committarlo su NebbieArcane.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "${HOME}/.config/nebbie/mud-dev.env" ]; then
	# shellcheck source=/dev/null
	source "${HOME}/.config/nebbie/mud-dev.env"
fi

# Stack compose (mysql_data/) — di solito NebbieArcane
if [ -z "${MUD_ROOT:-}" ]; then
	if [ -d "${HOME}/NebbieArcane/Server" ]; then
		MUD_ROOT="${HOME}/NebbieArcane/Server"
	else
		MUD_ROOT="$SCRIPT_REPO"
	fi
fi

# Fork con edit-portal
EDIT_REPO="${EDIT_REPO:-$SCRIPT_REPO}"

# Sorgente /app nel container mudcompiler (myst build & run)
MUD_APP_ROOT="${MUD_APP_ROOT:-$MUD_ROOT}"

ENVIRONMENT="${ENVIRONMENT:-devel}"
MUD_PORT="${MUD_PORT:-4002}"
MUD_DATA_DIR="${MUD_DATA_DIR:-lib}"
EDIT_API_PORT="${EDIT_API_PORT:-8090}"
EDIT_API_SECRET="${EDIT_API_SECRET:-nebbie-edit-dev-secret}"
EDIT_WEB_PORT="${EDIT_WEB_PORT:-3080}"

MUD_STACK_NETWORK="${MUD_STACK_NETWORK:-$(basename "$MUD_ROOT" | tr '[:upper:]' '[:lower:]')_default}"

if [ ! -f "$MUD_ROOT/docker-compose.yml" ]; then
	echo "ERRORE: MUD_ROOT=$MUD_ROOT senza docker-compose.yml" >&2
	exit 1
fi

# shellcheck source=scripts/load-mysql-conf.sh
ROOT="$MUD_ROOT"
source "${MUD_ROOT}/scripts/load-mysql-conf.sh"

if docker compose version >/dev/null 2>&1; then
	COMPOSE='docker compose'
elif command -v docker-compose >/dev/null 2>&1; then
	COMPOSE='docker-compose'
else
	echo "ERRORE: né 'docker compose' né 'docker-compose' trovati." >&2
	exit 1
fi

compose() {
	(cd "$MUD_ROOT" && $COMPOSE "$@")
}

compose_edit() {
	if [ ! -f "$EDIT_REPO/docker-compose.edit-portal.yml" ]; then
		echo "ERRORE: EDIT_REPO=$EDIT_REPO senza docker-compose.edit-portal.yml" >&2
		return 1
	fi
	(
		cd "$EDIT_REPO"
		export MUD_STACK_NETWORK EDIT_API_SECRET EDIT_WEB_PORT
		$COMPOSE -f docker-compose.edit-portal.yml "$@"
	)
}

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
		echo "Rimozione container orphan server-mudcompiler-run-*..."
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
		echo "Avvio mysql e adminer (MUD_ROOT=$MUD_ROOT)..."
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
		echo "Riavvio container mudcompiler..."
		docker start mudcompiler
		sleep 2
		if find_mudcompiler_container >/dev/null; then
			return 0
		fi
	fi

	echo "Creazione mudcompiler (--name mudcompiler, /app <- $MUD_APP_ROOT)..."
	if compose run -d --name mudcompiler --service-ports \
		-v "${MUD_APP_ROOT}:/app" \
		--entrypoint /bin/bash mudcompiler -c 'sleep infinity'; then
		sleep 2
		if find_mudcompiler_container >/dev/null; then
			echo "Container mudcompiler creato."
			return 0
		fi
	fi

	echo "ERRORE: impossibile avviare mudcompiler." >&2
	echo "Porte occupate? ss -tlnp | grep -E '400|8090'" >&2
	echo "Su NebbieArcane: copia Confs/docker-compose.override.edit-api.example → docker-compose.override.yml" >&2
	return 1
}

cmd_start_edit() {
	ensure_mysql_stack
	if ! find_mudcompiler_container >/dev/null; then
		print_warn "mudcompiler non attivo — API edit non disponibile"
	fi
	echo "Avvio edit-portal da EDIT_REPO=$EDIT_REPO (rete $MUD_STACK_NETWORK)..."
	export EDIT_API_SECRET EDIT_WEB_PORT
	compose_edit up -d --build edit-portal
	echo "Web UI: http://localhost:${EDIT_WEB_PORT}/"
}

cmd_stop_edit() {
	compose_edit stop edit-portal 2>/dev/null || true
	compose_edit rm -f edit-portal 2>/dev/null || true
	echo "edit-portal fermato."
}

cmd_status() {
	local mudc=''
	local mysql_up=0 myst_up=0 edit_up=0

	print_header "Percorsi"
	echo "  MUD_ROOT:      $MUD_ROOT (compose mysql, git pull origin)"
	echo "  MUD_APP_ROOT:  $MUD_APP_ROOT (sorgente myst in container)"
	echo "  EDIT_REPO:     $EDIT_REPO (edit-portal)"
	echo "  Rete Docker:   $MUD_STACK_NETWORK"
	echo "  Porta mud:     $MUD_PORT | Edit API: $EDIT_API_PORT | Web: $EDIT_WEB_PORT"

	print_header "Docker Compose (MUD_ROOT)"
	if service_running mysql; then
		mysql_up=1
		print_ok "mysql"
	else
		print_warn "mysql non in esecuzione"
		print_do "./scripts/mud-dev.sh start-mud"
	fi
	if service_running adminer; then
		print_ok "adminer (http://localhost:8080)"
	fi
	if docker ps --filter 'name=^nebbie-edit-portal$' --format '{{.Names}}' | grep -q .; then
		edit_up=1
		print_ok "edit-portal (http://localhost:${EDIT_WEB_PORT})"
	else
		print_warn "edit-portal non in esecuzione"
		print_do "./scripts/mud-dev.sh start-edit"
	fi

	print_header "mudcompiler / myst"
	if mudc="$(find_mudcompiler_container)"; then
		print_ok "container: $mudc"
		docker ps --filter "name=$mudc" --format '  Ports: {{.Ports}}'
		if myst_running "$mudc"; then
			myst_up=1
			print_ok "myst attivo"
			echo "  $(myst_pgrep_line "$mudc")"
		else
			print_warn "myst non attivo"
			print_do "./scripts/mud-dev.sh start-mud"
		fi
		if docker exec "$mudc" test -x "/app/mudroot/myst" 2>/dev/null; then
			print_ok "/app/mudroot/myst presente"
		else
			print_warn "myst non compilato in $MUD_APP_ROOT"
			print_do "docker exec -it $mudc bash -c 'cd /app && ./build.sh devel'"
		fi
	else
		print_warn "nessun container mudcompiler"
		print_do "./scripts/mud-dev.sh start-mud"
	fi

	if port_open "$EDIT_API_PORT"; then
		print_ok "porta host $EDIT_API_PORT aperta"
	else
		print_warn "porta $EDIT_API_PORT chiusa (override 8090 + myst con edit_portal?)"
	fi

	if [ "$mysql_up" -eq 1 ] && mysql_ping; then
		print_ok "mysql ping"
	fi

	if port_open "$MUD_PORT" && [ "$myst_up" -eq 1 ]; then
		print_ok "telnet localhost $MUD_PORT"
	fi

	print_header "Riepilogo"
	if [ "$myst_up" -eq 1 ]; then
		echo "  MUD ok."
		[ "$edit_up" -eq 1 ] && echo "  Edit: http://localhost:${EDIT_WEB_PORT}/"
		return 0
	fi
	echo "  ./scripts/mud-dev.sh start-mud  (o start con config edit)"
	return 1
}

cmd_start_mud() {
	ensure_mysql_stack
	ensure_mudcompiler_container

	local mudc
	mudc="$(find_mudcompiler_container)"

	if myst_is_alive "$mudc"; then
		echo "myst già in esecuzione:"
		myst_pgrep_line "$mudc"
		return 0
	fi
	if myst_has_zombie "$mudc"; then
		force_cleanup_myst "$mudc"
		mudc="$(find_mudcompiler_container)"
	fi

	docker exec "$mudc" bash -c "
		set -e
		cd /app
		ln -sfn ../pages mudroot/pages 2>/dev/null || true
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
		echo "myst avviato (sorgente $MUD_APP_ROOT):"
		myst_pgrep_line "$mudc"
		echo "telnet localhost $MUD_PORT"
	else
		echo "ERRORE: myst non partito." >&2
		docker exec "$mudc" tail -20 /app/mudroot/errors.log 2>/dev/null || true
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
	exec compose run --rm -it --service-ports \
		-v "${MUD_APP_ROOT}:/app" \
		--entrypoint /bin/bash mudcompiler
}

cmd_stop_mud() {
	local mudc
	if mudc="$(find_mudcompiler_container)"; then
		force_cleanup_myst "$mudc"
		echo "myst terminato."
	else
		echo "Nessun mudcompiler attivo."
	fi
}

cmd_logs() {
	local mudc lines="${1:-40}"
	if ! mudc="$(find_mudcompiler_container)"; then
		echo "Nessun mudcompiler." >&2
		return 1
	fi
	docker exec "$mudc" tail -n "$lines" /app/mudroot/errors.log 2>/dev/null || true
	docker exec "$mudc" grep edit_portal /app/mudroot/alarmud.log 2>/dev/null | tail -10 || true
}

cmd_stop_all() {
	cmd_stop_mud
	cmd_stop_edit
	docker rm -f mudcompiler 2>/dev/null || true
	cleanup_orphan_mudcompiler_runs
	docker ps -aq --filter 'ancestor=nebbiearcane/mudcompiler:latest' | xargs -r docker rm -f 2>/dev/null || true
	compose down --remove-orphans 2>/dev/null || compose stop mysql adminer 2>/dev/null || true
	echo "Stack fermato (mysql_data in $MUD_ROOT/mysql_data conservato)."
}

usage() {
	cat <<EOF
Uso: ./scripts/mud-dev.sh <comando>

Setup due repo (vedi docs/edit-portal-two-repos.md):
  MUD_ROOT=$MUD_ROOT
  EDIT_REPO=$EDIT_REPO
  MUD_APP_ROOT=$MUD_APP_ROOT

Comandi: status | start | start-mud | start-edit | start-stack | stop-mud | stop-edit | stop-all | logs

Config opzionale: ~/.config/nebbie/mud-dev.env
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
