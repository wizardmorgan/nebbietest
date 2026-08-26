#!/bin/bash
# Dev Docker: NebbieArcane (Razze) + fork edit-portal (due repo).
# Config: ~/.config/nebbie/mud-dev.env (vedi docs/nebbie-mud-dev.env.example)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "${HOME}/.config/nebbie/mud-dev.env" ]; then
	# shellcheck source=/dev/null
	source "${HOME}/.config/nebbie/mud-dev.env"
fi

if [ -z "${MUD_ROOT:-}" ]; then
	if [ -d "${HOME}/NebbieArcane/Server" ]; then
		MUD_ROOT="${HOME}/NebbieArcane/Server"
	else
		MUD_ROOT="$SCRIPT_REPO"
	fi
fi

EDIT_REPO="${EDIT_REPO:-$SCRIPT_REPO}"
MUD_APP_ROOT="${MUD_APP_ROOT:-$MUD_ROOT}"

ENVIRONMENT="${ENVIRONMENT:-devel}"
MUD_PORT="${MUD_PORT:-4002}"
MUD_DATA_DIR="${MUD_DATA_DIR:-lib}"
EDIT_API_PORT="${EDIT_API_PORT:-8090}"
EDIT_API_SECRET="${EDIT_API_SECRET:-nebbie-edit-dev-secret}"
EDIT_WEB_PORT="${EDIT_WEB_PORT:-3080}"

RAZZE_REMOTE="${RAZZE_REMOTE:-origin}"
RAZZE_BRANCH="${RAZZE_BRANCH:-feature/Razze}"
EDIT_REMOTE="${EDIT_REMOTE:-mine}"
EDIT_BRANCH="${EDIT_BRANCH:-feature/edit-portal}"
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"

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

myst_running() {
	local c="$1"
	myst_is_alive "$c"
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

ensure_docker_override() {
	local example="$EDIT_REPO/Confs/docker-compose.override.edit-api.example"
	local target="$MUD_ROOT/docker-compose.override.yml"
	if [ ! -f "$target" ] && [ -f "$example" ]; then
		echo "Copia override API edit → $target"
		cp "$example" "$target"
	fi
}

ensure_edit_remote() {
	(
		cd "$EDIT_REPO"
		if ! git remote get-url "$EDIT_REMOTE" >/dev/null 2>&1; then
			echo "Aggiunta remote $EDIT_REMOTE → https://github.com/wizardmorgan/nebbietest.git"
			git remote add "$EDIT_REMOTE" https://github.com/wizardmorgan/nebbietest.git
		fi
	)
}

ensure_upstream_remote() {
	(
		cd "$EDIT_REPO"
		if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
			echo "Aggiunta remote $UPSTREAM_REMOTE → https://github.com/NebbieArcane/Server.git"
			git remote add "$UPSTREAM_REMOTE" https://github.com/NebbieArcane/Server.git
		fi
	)
}

git_discard_local_file() {
	local repo="$1" path="$2"
	if [ ! -d "$repo/.git" ]; then
		return 0
	fi
	(
		cd "$repo"
		if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
			if ! git diff --quiet "$path" 2>/dev/null || ! git diff --cached --quiet "$path" 2>/dev/null; then
				echo "[$repo] ripristino $path (modifiche locali) per permettere pull"
				git checkout -- "$path"
			fi
		else
			if [ -f "$path" ]; then
				echo "[$repo] rimuovo $path untracked che blocca merge"
				rm -f "$path"
			fi
		fi
	)
}

git_pull_branch() {
	local repo="$1" remote="$2" branch="$3"
	(
		cd "$repo"
		git fetch "$remote" "$branch"
		if git merge-base --is-ancestor HEAD FETCH_HEAD 2>/dev/null; then
			git merge --ff-only FETCH_HEAD
		elif git merge-base --is-ancestor FETCH_HEAD HEAD 2>/dev/null; then
			echo "[$repo] già aggiornato rispetto a $remote/$branch"
		else
			echo "[$repo] merge $remote/$branch (branch divergenti)"
			git merge --no-edit FETCH_HEAD
		fi
	)
}

cmd_sync_razze() {
	echo "=== sync-razze: $MUD_ROOT ($RAZZE_REMOTE/$RAZZE_BRANCH) ==="
	git_pull_branch "$MUD_ROOT" "$RAZZE_REMOTE" "$RAZZE_BRANCH"
	ensure_docker_override
	echo "sync-razze ok."
}

cmd_sync_edit() {
	echo "=== sync-edit: $EDIT_REPO ($EDIT_REMOTE/$EDIT_BRANCH) ==="
	ensure_edit_remote
	git_discard_local_file "$EDIT_REPO" scripts/mud-dev.sh
	git_discard_local_file "$EDIT_REPO" pages/wizhelptbl.stamp
	git_pull_branch "$EDIT_REPO" "$EDIT_REMOTE" "$EDIT_BRANCH"
	chmod +x "$EDIT_REPO/scripts/mud-dev.sh" 2>/dev/null || true
	echo "sync-edit ok."
}

cmd_sync_all() {
	cmd_sync_razze
	echo "=== merge Razze in EDIT_REPO ==="
	ensure_upstream_remote
	ensure_edit_remote
	git_discard_local_file "$EDIT_REPO" scripts/mud-dev.sh
	(
		cd "$EDIT_REPO"
		git fetch "$UPSTREAM_REMOTE" "$RAZZE_BRANCH"
		if git merge --no-edit "$UPSTREAM_REMOTE/$RAZZE_BRANCH"; then
			echo "merge $UPSTREAM_REMOTE/$RAZZE_BRANCH ok"
		else
			echo "ERRORE: conflitti merge in $EDIT_REPO — risolvi, commit, poi riprova." >&2
			exit 1
		fi
	)
	git_pull_branch "$EDIT_REPO" "$EDIT_REMOTE" "$EDIT_BRANCH"
	chmod +x "$EDIT_REPO/scripts/mud-dev.sh" 2>/dev/null || true
	echo "sync-all ok."
}

cmd_build() {
	echo "=== build myst (sorgente $MUD_APP_ROOT) ==="
	ensure_docker_override
	compose run --rm --entrypoint "" \
		-v "${MUD_APP_ROOT}:/app" \
		mudcompiler ./build.sh devel
	echo "build myst ok."
}

cmd_build_edit() {
	echo "=== build edit-portal ==="
	export MUD_STACK_NETWORK EDIT_API_SECRET EDIT_WEB_PORT
	compose_edit build edit-portal
	echo "build edit-portal ok."
}

cmd_update_razze() {
	cmd_sync_razze
	cmd_build
}

cmd_update_edit() {
	cmd_sync_edit
	cmd_build_edit
}

cmd_deploy_edit() {
	echo "=== deploy-edit: sync fork + build myst + build portal + start ==="
	cmd_sync_edit
	cmd_build
	cmd_build_edit
	cmd_start
	echo "deploy-edit ok. Web: http://localhost:${EDIT_WEB_PORT}/"
}

cmd_update_all() {
	cmd_sync_all
	cmd_build
	cmd_build_edit
}

cmd_health() {
	echo "=== health ==="
	if port_open "$EDIT_WEB_PORT"; then
		print_ok "edit-portal porta $EDIT_WEB_PORT"
		curl -sf "http://localhost:${EDIT_WEB_PORT}/api/health" || echo "(curl health fallito)"
	else
		print_warn "edit-portal porta $EDIT_WEB_PORT chiusa"
	fi
	if port_open "$EDIT_API_PORT"; then
		print_ok "myst API porta $EDIT_API_PORT"
		curl -sf -X POST "http://localhost:${EDIT_API_PORT}/internal/ping" \
			-H "x-edit-api-secret: ${EDIT_API_SECRET}" || echo "(curl ping fallito — secret?)"
	else
		print_warn "myst API porta $EDIT_API_PORT chiusa"
	fi
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
	return 1
}

cmd_start_edit() {
	ensure_mysql_stack
	if ! find_mudcompiler_container >/dev/null; then
		print_warn "mudcompiler non attivo — API edit non disponibile"
	fi
	echo "Avvio edit-portal (EDIT_REPO=$EDIT_REPO, rete $MUD_STACK_NETWORK)..."
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
	echo "  MUD_ROOT:      $MUD_ROOT"
	echo "  MUD_APP_ROOT:  $MUD_APP_ROOT"
	echo "  EDIT_REPO:     $EDIT_REPO"
	echo "  Rete Docker:   $MUD_STACK_NETWORK"
	echo "  Porta mud:     $MUD_PORT | Edit API: $EDIT_API_PORT | Web: $EDIT_WEB_PORT"

	print_header "Git (branch attuale)"
	if [ -d "$MUD_ROOT/.git" ]; then
		echo "  MUD_ROOT:  $(cd "$MUD_ROOT" && git branch --show-current) @ $(cd "$MUD_ROOT" && git rev-parse --short HEAD)"
	fi
	if [ -d "$EDIT_REPO/.git" ]; then
		echo "  EDIT_REPO: $(cd "$EDIT_REPO" && git branch --show-current) @ $(cd "$EDIT_REPO" && git rev-parse --short HEAD)"
	fi

	print_header "Docker Compose (MUD_ROOT)"
	if service_running mysql; then
		mysql_up=1
		print_ok "mysql"
	else
		print_warn "mysql non in esecuzione"
	fi
	if service_running adminer; then
		print_ok "adminer (http://localhost:8080)"
	fi
	if docker ps --filter 'name=^nebbie-edit-portal$' --format '{{.Names}}' | grep -q .; then
		edit_up=1
		print_ok "edit-portal (http://localhost:${EDIT_WEB_PORT})"
	else
		print_warn "edit-portal non in esecuzione"
	fi

	print_header "mudcompiler / myst"
	if mudc="$(find_mudcompiler_container)"; then
		print_ok "container: $mudc"
		docker ps --filter "name=$mudc" --format '  Ports: {{.Ports}}'
		if myst_running "$mudc"; then
			myst_up=1
			print_ok "myst attivo"
		else
			print_warn "myst non attivo"
		fi
	else
		print_warn "nessun container mudcompiler"
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
	echo "  Prova: $0 start   oppure   $0 dev"
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

cmd_dev() {
	echo "=== dev: sync-all + build + start ==="
	cmd_update_all
	cmd_start
}

usage() {
	cat <<EOF
mud-dev.sh — MUD NebbieArcane + edit-portal (due repo)

Config: ~/.config/nebbie/mud-dev.env
  MUD_ROOT=$MUD_ROOT        ($RAZZE_REMOTE/$RAZZE_BRANCH)
  EDIT_REPO=$EDIT_REPO      ($EDIT_REMOTE/$EDIT_BRANCH)
  MUD_APP_ROOT=$MUD_APP_ROOT

SYNC (git)
  sync-razze      pull Montero su NebbieArcane (solo MUD_ROOT)
  sync-edit       pull fork edit-portal su EDIT_REPO
  sync-all        sync-razze + merge Razze in EDIT_REPO + pull edit-portal

BUILD
  build           compila myst (./build.sh devel, sorgente MUD_APP_ROOT)
  build-edit      rebuild immagine Docker edit-portal

UPDATE (sync + build)
  update-razze    sync-razze + build myst
  update-edit     sync-edit + build-edit
  update-all      sync-all + build myst + build-edit
  deploy-edit     sync-edit + build myst + build-edit + start (workflow portale)

AVVIO / STOP
  start           myst (con edit API) + edit-portal + status
  start-mud       solo myst
  start-edit      solo web edit-portal (:${EDIT_WEB_PORT})
  start-stack     shell interattiva nel container mudcompiler
  stop-mud        termina myst
  stop-edit       ferma edit-portal
  stop-all        myst + edit-portal + mysql/adminer (DB conservato)

INFO
  status          diagnostica stack e git
  logs [righe]    tail errors.log / edit_portal in myst
  health          curl health web + ping API myst
  dev             update-all + start (workflow dopo update Montero)

  help | --help   questo messaggio (default senza argomenti)

Esempi:
  $0 dev                    # Montero ha pushato: pull, build, avvio tutto
  $0 update-razze && $0 start-mud   # solo upstream + mud telnet
  $0 sync-edit && $0 build-edit && $0 start-edit
  $0 deploy-edit              # pull fork + build tutto + avvio (docker-vms)

Vedi docs/edit-portal-two-repos.md
EOF
}

main() {
	local cmd="${1:-help}"
	case "$cmd" in
	help | -h | --help) usage ;;
	status) cmd_status ;;
	health) cmd_health ;;
	sync-razze) cmd_sync_razze ;;
	sync-edit) cmd_sync_edit ;;
	sync-all) cmd_sync_all ;;
	build) cmd_build ;;
	build-edit) cmd_build_edit ;;
	update-razze) cmd_update_razze ;;
	update-edit) cmd_update_edit ;;
	deploy-edit) cmd_deploy_edit ;;
	update-all) cmd_update_all ;;
	dev) cmd_dev ;;
	start) cmd_start ;;
	start-mud) cmd_start_mud ;;
	start-edit) cmd_start_edit ;;
	start-stack) cmd_start_stack ;;
	stop-mud) cmd_stop_mud ;;
	stop-edit) cmd_stop_edit ;;
	stop-all) cmd_stop_all ;;
	logs) cmd_logs "${2:-40}" ;;
	*)
		echo "Comando sconosciuto: $cmd" >&2
		echo "" >&2
		usage >&2
		exit 1
		;;
	esac
}

main "$@"
