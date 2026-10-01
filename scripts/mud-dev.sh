#!/bin/bash
# Dev Docker nucbuntu:
#   MUD (myst/C++)  → ~/NebbieArcane/Server
#   UI portale      → ~/NebbieArcane/edit-portal  (NebbieArcane/edit-portal, non il fork)
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

# C++ / myst: clone Server (branch con edit_portal, tipicamente feature/edit-portal)
EDIT_REPO="${EDIT_REPO:-$MUD_ROOT}"
MUD_APP_ROOT="${MUD_APP_ROOT:-$EDIT_REPO}"

# UI ufficiale (repo Node): default clone dedicato
if [ -z "${PORTAL_UI_ROOT:-}" ]; then
	if [ -d "${HOME}/NebbieArcane/edit-portal/.git" ]; then
		PORTAL_UI_ROOT="${HOME}/NebbieArcane/edit-portal"
	elif [ -f "$SCRIPT_REPO/public/app.js" ] && [ -f "$SCRIPT_REPO/server.js" ]; then
		# mud-dev.sh gira dal clone NebbieArcane/edit-portal
		PORTAL_UI_ROOT="$SCRIPT_REPO"
	elif [ -d "$EDIT_REPO/edit-portal" ]; then
		# legacy: UI annidata nel clone mud
		PORTAL_UI_ROOT="$EDIT_REPO/edit-portal"
	else
		PORTAL_UI_ROOT="${HOME}/NebbieArcane/edit-portal"
	fi
fi

ENVIRONMENT="${ENVIRONMENT:-devel}"
MUD_PORT="${MUD_PORT:-4002}"
MUD_DATA_DIR="${MUD_DATA_DIR:-mudroot/lib}"
EDIT_API_PORT="${EDIT_API_PORT:-8090}"
EDIT_API_SECRET="${EDIT_API_SECRET:-nebbie-edit-dev-secret}"
EDIT_WEB_PORT="${EDIT_WEB_PORT:-3080}"

RAZZE_REMOTE="${RAZZE_REMOTE:-upstream}"
RAZZE_BRANCH="${RAZZE_BRANCH:-feature/Razze}"
# C++ portal: remote fork mud (finché edit_portal.cpp non è su NebbieArcane/Server)
EDIT_REMOTE="${EDIT_REMOTE:-mine}"
EDIT_BRANCH="${EDIT_BRANCH:-feature/edit-portal}"
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
# UI: NebbieArcane/edit-portal
PORTAL_UI_REMOTE="${PORTAL_UI_REMOTE:-origin}"
PORTAL_UI_BRANCH="${PORTAL_UI_BRANCH:-develop}"
PORTAL_UI_GIT_URL="${PORTAL_UI_GIT_URL:-git@github.com:NebbieArcane/edit-portal.git}"
PORTAL_UI_SSH_KEY="${PORTAL_UI_SSH_KEY:-${HOME}/.ssh/edit_portal_deploy}"

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

portal_ui_app_js() {
	if [ -f "$PORTAL_UI_ROOT/public/app.js" ]; then
		echo "$PORTAL_UI_ROOT/public/app.js"
	elif [ -f "$PORTAL_UI_ROOT/edit-portal/public/app.js" ]; then
		echo "$PORTAL_UI_ROOT/edit-portal/public/app.js"
	elif [ -f "$EDIT_REPO/edit-portal/public/app.js" ]; then
		echo "$EDIT_REPO/edit-portal/public/app.js"
	else
		return 1
	fi
}

compose() {
	(cd "$MUD_ROOT" && $COMPOSE "$@")
}

compose_edit() {
	# Preferisci repo ufficiale (docker-compose.yml, build: .)
	if [ -f "$PORTAL_UI_ROOT/docker-compose.yml" ] && [ -f "$PORTAL_UI_ROOT/server.js" ]; then
		(
			cd "$PORTAL_UI_ROOT"
			export MUD_STACK_NETWORK EDIT_API_SECRET EDIT_WEB_PORT
			$COMPOSE -f docker-compose.yml "$@"
		)
		return $?
	fi
	# Legacy: overlay nel clone mud (build: ./edit-portal)
	if [ -f "$EDIT_REPO/docker-compose.edit-portal.yml" ]; then
		(
			cd "$EDIT_REPO"
			export MUD_STACK_NETWORK EDIT_API_SECRET EDIT_WEB_PORT
			$COMPOSE -f docker-compose.edit-portal.yml "$@"
		)
		return $?
	fi
	echo "ERRORE: nessun compose UI. Clona NebbieArcane/edit-portal in PORTAL_UI_ROOT=$PORTAL_UI_ROOT" >&2
	return 1
}

portal_git_ssh_env() {
	# Evita rewrite HTTPS Cursor; usa deploy key se presente.
	if [ -f "$PORTAL_UI_SSH_KEY" ]; then
		export GIT_SSH_COMMAND="ssh -i ${PORTAL_UI_SSH_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
		export GIT_CONFIG_GLOBAL=/dev/null
		export GIT_CONFIG_SYSTEM=/dev/null
	fi
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

mudcompiler_container_mount() {
	local mudc="$1"
	docker inspect "$mudc" --format '{{range .Mounts}}{{if eq .Destination "/app"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || true
}

ensure_mudcompiler_mount() {
	local mudc mount expected
	expected="$(cd "$MUD_APP_ROOT" && pwd)"
	if ! mudc="$(find_mudcompiler_container)"; then
		return 0
	fi
	mount="$(mudcompiler_container_mount "$mudc")"
	if [ -n "$mount" ] && [ "$mount" != "$expected" ]; then
		echo "ATTENZIONE: container mudcompiler monta $mount" >&2
		echo "  atteso: $expected (MUD_APP_ROOT)" >&2
		echo "  Ricreo il container (bind mount fissato alla creazione)..." >&2
		docker rm -f "$mudc"
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
	local example target
	target="$MUD_ROOT/docker-compose.override.yml"
	for example in \
		"$EDIT_REPO/Confs/docker-compose.override.edit-api.example" \
		"$MUD_ROOT/Confs/docker-compose.override.edit-api.example" \
		"$SCRIPT_REPO/docs/docker-compose.override.edit-api.example"; do
		if [ ! -f "$target" ] && [ -f "$example" ]; then
			echo "Copia override API edit → $target"
			cp "$example" "$target"
			return 0
		fi
	done
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
	local repo="${1:-$EDIT_REPO}"
	(
		cd "$repo"
		if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
			echo "Aggiunta remote $UPSTREAM_REMOTE → https://github.com/NebbieArcane/Server.git"
			git remote add "$UPSTREAM_REMOTE" https://github.com/NebbieArcane/Server.git
		fi
	)
}

ensure_portal_ui_clone() {
	if [ -d "$PORTAL_UI_ROOT/.git" ] && [ -f "$PORTAL_UI_ROOT/server.js" ]; then
		return 0
	fi
	if [ -f "$PORTAL_UI_ROOT/server.js" ] && [ ! -d "$PORTAL_UI_ROOT/.git" ]; then
		# nested legacy path without own git — ok for compose, not for sync-ui
		return 0
	fi
	echo "=== clone UI ufficiale → $PORTAL_UI_ROOT ==="
	mkdir -p "$(dirname "$PORTAL_UI_ROOT")"
	portal_git_ssh_env
	if [ -f "$PORTAL_UI_SSH_KEY" ]; then
		GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
			git clone "$PORTAL_UI_GIT_URL" "$PORTAL_UI_ROOT"
	else
		echo "AVVISO: $PORTAL_UI_SSH_KEY assente — provo clone HTTPS (repo privato: serve auth)." >&2
		git clone "https://github.com/NebbieArcane/edit-portal.git" "$PORTAL_UI_ROOT"
	fi
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
	# Preferisci merge Razze sul clone C++ (EDIT_REPO), se distinto da MUD_ROOT
	local repo="$EDIT_REPO"
	if [ ! -d "$repo/.git" ]; then
		repo="$MUD_ROOT"
	fi
	ensure_upstream_remote "$repo"
	(
		cd "$repo"
		# Se RAZZE_REMOTE manca, usa upstream
		if ! git remote get-url "$RAZZE_REMOTE" >/dev/null 2>&1; then
			RAZZE_REMOTE="$UPSTREAM_REMOTE"
		fi
		git fetch "$RAZZE_REMOTE" "$RAZZE_BRANCH"
		if git merge --no-edit "$RAZZE_REMOTE/$RAZZE_BRANCH"; then
			echo "merge $RAZZE_REMOTE/$RAZZE_BRANCH ok"
		else
			echo "ERRORE: conflitti merge Razze in $repo — vedi docs/sync-razze-procedure.md" >&2
			exit 1
		fi
	)
	ensure_docker_override
	echo "sync-razze ok."
}

# C++ / API myst (edit_portal.cpp) dal remote mud (mine/feature/edit-portal)
cmd_sync_mud() {
	echo "=== sync-mud (C++ portal): $EDIT_REPO ($EDIT_REMOTE/$EDIT_BRANCH) ==="
	ensure_edit_remote
	git_discard_local_file "$EDIT_REPO" pages/wizhelptbl.stamp
	git_pull_branch "$EDIT_REPO" "$EDIT_REMOTE" "$EDIT_BRANCH"
	chmod +x "$EDIT_REPO/scripts/"*.sh 2>/dev/null || true
	echo "sync-mud ok."
}

# UI ufficiale NebbieArcane/edit-portal
cmd_sync_ui() {
	echo "=== sync-ui: $PORTAL_UI_ROOT ($PORTAL_UI_REMOTE/$PORTAL_UI_BRANCH) ==="
	ensure_portal_ui_clone
	if [ ! -d "$PORTAL_UI_ROOT/.git" ]; then
		echo "ERRORE: $PORTAL_UI_ROOT non e' un clone git (UI ufficiale)." >&2
		echo "  Clona: git clone $PORTAL_UI_GIT_URL $PORTAL_UI_ROOT" >&2
		exit 1
	fi
	portal_git_ssh_env
	(
		cd "$PORTAL_UI_ROOT"
		git fetch "$PORTAL_UI_REMOTE" "$PORTAL_UI_BRANCH"
		git checkout "$PORTAL_UI_BRANCH"
		if git merge-base --is-ancestor HEAD FETCH_HEAD 2>/dev/null; then
			git merge --ff-only FETCH_HEAD
		elif git merge-base --is-ancestor FETCH_HEAD HEAD 2>/dev/null; then
			echo "[UI] già aggiornato rispetto a $PORTAL_UI_REMOTE/$PORTAL_UI_BRANCH"
		else
			echo "[UI] reset --hard a $PORTAL_UI_REMOTE/$PORTAL_UI_BRANCH (working tree UI pulito richiesto)"
			git reset --hard "FETCH_HEAD"
		fi
	)
	chmod +x "$PORTAL_UI_ROOT/scripts/"*.sh 2>/dev/null || true
	echo "sync-ui ok. UI build: $(grep -E 'EDIT_PORTAL_UI_BUILD\s*=' "$(portal_ui_app_js)" 2>/dev/null | head -1 || echo '?')"
}

# Retrocompat: sync-edit = sync C++ mud (come prima) + sync UI ufficiale
cmd_sync_edit() {
	cmd_sync_mud
	cmd_sync_ui
}

cmd_sync_all() {
	# Tree mud pulito consigliato (stash) prima di sync-razze
	cmd_sync_razze
	cmd_sync_mud
	cmd_sync_ui
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
	cmd_sync_ui
	cmd_build_edit
}

cmd_deploy_edit() {
	echo "=== deploy-edit: sync mud C++ + UI ufficiale + build + start ==="
	cmd_sync_mud
	cmd_sync_ui
	cmd_build
	cmd_stop_mud
	cmd_build_edit
	cmd_start
	echo "deploy-edit ok. Web: http://localhost:${EDIT_WEB_PORT}/"
}

cmd_rebuild_myst() {
	cmd_build
	ensure_mudcompiler_mount
	ensure_mudcompiler_container
	cmd_stop_mud
	cmd_start_mud
	echo ""
	echo "Verifica: ./scripts/verify-myst-portal.sh"
}

cmd_doctor() {
	local mudc mount expected host_md5 cont_md5
	expected="$(cd "$MUD_APP_ROOT" && pwd)"
	print_header "Git"
	if [ -d "$EDIT_REPO/.git" ]; then
		echo "  branch: $(cd "$EDIT_REPO" && git branch --show-current)"
		echo "  HEAD:   $(cd "$EDIT_REPO" && git rev-parse --short HEAD)"
		git -C "$EDIT_REPO" status -sb | head -5
	fi
	print_header "Path config"
	echo "  MUD_APP_ROOT: $expected"
	if [ -f "$expected/mudroot/myst" ]; then
		host_md5="$(md5sum "$expected/mudroot/myst" | awk '{print $1}')"
		echo "  host mudroot/myst: $(ls -la "$expected/mudroot/myst" | awk '{print $5, $6, $7, $8}') md5=$host_md5"
	else
		echo "  host mudroot/myst: MANCANTE"
	fi
	print_header "Container mudcompiler"
	if mudc="$(find_mudcompiler_container)"; then
		mount="$(mudcompiler_container_mount "$mudc")"
		echo "  container: $mudc"
		echo "  mount /app: ${mount:-?}"
		if [ "$mount" != "$expected" ]; then
			print_warn "MOUNT DIVERSO da MUD_APP_ROOT — build e processo vedono directory diverse"
			echo "  Fix: docker rm -f mudcompiler && ./scripts/mud-dev.sh rebuild-myst"
		fi
		cont_md5="$(docker exec "$mudc" md5sum /app/mudroot/myst 2>/dev/null | awk '{print $1}' || true)"
		echo "  container myst md5: ${cont_md5:-n/a}"
		if [ -n "$host_md5" ] && [ -n "$cont_md5" ] && [ "$host_md5" != "$cont_md5" ]; then
			print_warn "MD5 host != container — myst in esecuzione non è il binario appena compilato"
		fi
		docker exec "$mudc" pgrep -a myst 2>/dev/null || echo "  myst non in esecuzione"
	else
		print_warn "nessun container mudcompiler"
	fi
	print_header "API ping"
	curl -sf -X POST "http://localhost:${EDIT_API_PORT}/internal/ping" \
		-H "x-edit-api-secret: ${EDIT_API_SECRET}" \
		-H "Content-Type: application/json" -d '{}' | python3 -m json.tool 2>/dev/null || echo "(ping fallito)"
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
	ensure_mudcompiler_mount

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
	echo "Avvio edit-portal (PORTAL_UI_ROOT=$PORTAL_UI_ROOT, rete $MUD_STACK_NETWORK)..."
	export EDIT_API_SECRET EDIT_WEB_PORT
	# MAI --remove-orphans qui: il compose edit-portal non elenca mysql/adminer,
	# quindi orphans li UCCIDE (come successso su nucbuntu).
	docker rm -f nebbie-edit-portal 2>/dev/null || true
	local host_app
	if host_app="$(portal_ui_app_js)"; then
		echo "Host app.js marker:"
		grep -n 'EDIT_PORTAL_UI_BUILD' "$host_app" | head -3 || \
			print_warn "EDIT_PORTAL_UI_BUILD assente su host — sync-ui incompleto?"
	else
		print_warn "public/app.js non trovato — esegui: $0 sync-ui"
	fi
	compose_edit up -d --build --force-recreate edit-portal
	# mysql potrebbe essere stato stoppato da altri comandi: ripristina
	ensure_mysql_stack
	echo "Attesa edit-portal..."
	local i
	for i in $(seq 1 30); do
		if curl -sf "http://localhost:${EDIT_WEB_PORT}/api/health" >/dev/null 2>&1; then
			break
		fi
		sleep 0.5
	done
	local health expected_ui
	health="$(curl -sf "http://localhost:${EDIT_WEB_PORT}/api/health" 2>/dev/null || true)"
	echo "health: ${health:-"(nessuna risposta)"}"
	expected_ui="$(grep -E 'EDIT_PORTAL_UI_BUILD\s*=' "$(portal_ui_app_js 2>/dev/null || true)" 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1)"
	expected_ui="${expected_ui:-?}"
	if docker exec nebbie-edit-portal grep -q "EDIT_PORTAL_UI_BUILD = ${expected_ui}" /app/public/app.js 2>/dev/null; then
		echo "OK: container ha app.js UI build ${expected_ui}"
	else
		print_warn "app.js nel container senza UI build ${expected_ui} — dump:"
		docker exec nebbie-edit-portal head -n 15 /app/public/app.js 2>/dev/null || \
			echo "(docker exec fallito — container giu?)"
	fi
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
	echo "  MUD_ROOT:       $MUD_ROOT"
	echo "  MUD_APP_ROOT:   $MUD_APP_ROOT"
	echo "  EDIT_REPO(C++): $EDIT_REPO"
	echo "  PORTAL_UI_ROOT: $PORTAL_UI_ROOT"
	echo "  Rete Docker:    $MUD_STACK_NETWORK"
	echo "  Porta mud:      $MUD_PORT | Edit API: $EDIT_API_PORT | Web: $EDIT_WEB_PORT"

	print_header "Git (branch attuale)"
	if [ -d "$MUD_ROOT/.git" ]; then
		echo "  MUD_ROOT:  $(cd "$MUD_ROOT" && git branch --show-current) @ $(cd "$MUD_ROOT" && git rev-parse --short HEAD)"
	fi
	if [ -d "$EDIT_REPO/.git" ] && [ "$EDIT_REPO" != "$MUD_ROOT" ]; then
		echo "  EDIT_REPO: $(cd "$EDIT_REPO" && git branch --show-current) @ $(cd "$EDIT_REPO" && git rev-parse --short HEAD)"
	fi
	if [ -d "$PORTAL_UI_ROOT/.git" ]; then
		echo "  PORTAL_UI: $(cd "$PORTAL_UI_ROOT" && git branch --show-current) @ $(cd "$PORTAL_UI_ROOT" && git rev-parse --short HEAD)"
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
		ln -sfn pages mudroot/pages 2>/dev/null || true
		cp -n myst.* mudroot/lib/ 2>/dev/null || true
		if [ ! -f mudroot/lib/edit_system.json ] && [ -f Confs/edit_system.default.json ]; then
			cp Confs/edit_system.default.json mudroot/lib/edit_system.json
		fi
		chmod u+rw mudroot/lib/edit_system.json 2>/dev/null || true
		if [ ! -x mudroot/myst ]; then
			echo 'ERRORE: mudroot/myst mancante — esegui build myst prima di start-mud' >&2
			exit 1
		fi
		export EDIT_API_PORT='${EDIT_API_PORT}'
		export EDIT_API_SECRET='${EDIT_API_SECRET}'
		export EDIT_SYSTEM_CONFIG='/app/mudroot/lib/edit_system.json'
		exec ./mudroot/myst -D -P $MUD_PORT -d $MUD_DATA_DIR -v 4
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
mud-dev.sh — MUD NebbieArcane/Server + UI NebbieArcane/edit-portal

Config: ~/.config/nebbie/mud-dev.env
  MUD_ROOT=$MUD_ROOT
  EDIT_REPO=$EDIT_REPO          (C++ / myst, tipicamente stesso di MUD_ROOT)
  PORTAL_UI_ROOT=$PORTAL_UI_ROOT  (UI ufficiale, repo Node)
  MUD_APP_ROOT=$MUD_APP_ROOT

SYNC (git)
  sync-razze      merge Montero ($RAZZE_REMOTE/$RAZZE_BRANCH) nel clone C++
  sync-mud        pull C++ portal ($EDIT_REMOTE/$EDIT_BRANCH) su EDIT_REPO
  sync-ui         pull UI ufficiale ($PORTAL_UI_REMOTE/$PORTAL_UI_BRANCH)
  sync-edit       sync-mud + sync-ui  (retrocompat)
  sync-all        sync-razze + sync-mud + sync-ui

BUILD
  build           compila myst (./build.sh devel, sorgente MUD_APP_ROOT)
  build-edit      rebuild immagine Docker edit-portal (da PORTAL_UI_ROOT)

UPDATE (sync + build)
  update-razze    sync-razze + build myst
  update-edit     sync-ui + build-edit
  update-all      sync-all + build myst + build-edit
  deploy-edit     sync-mud + sync-ui + build + start
  doctor          diagnostica mount/build/myst
  rebuild-myst    build + ricrea container se mount errato + riavvia myst

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
  dev             update-all + start

  help | --help   questo messaggio (default senza argomenti)

Esempi:
  $0 sync-ui && $0 build-edit && $0 start-edit   # solo UI ufficiale
  $0 sync-all && $0 build && $0 start            # Razze + C++ + UI
  $0 deploy-edit

Vedi docs/edit-portal-nucbuntu.md e docs/edit-portal-ssh-deploy.md
EOF
}

main() {
	local cmd="${1:-help}"
	case "$cmd" in
	help | -h | --help) usage ;;
	status) cmd_status ;;
	health) cmd_health ;;
	sync-razze) cmd_sync_razze ;;
	sync-mud) cmd_sync_mud ;;
	sync-ui | sync-portal) cmd_sync_ui ;;
	sync-edit) cmd_sync_edit ;;
	sync-all) cmd_sync_all ;;
	build) cmd_build ;;
	build-edit) cmd_build_edit ;;
	update-razze) cmd_update_razze ;;
	update-edit) cmd_update_edit ;;
	deploy-edit) cmd_deploy_edit ;;
	rebuild-myst) cmd_rebuild_myst ;;
	doctor) cmd_doctor ;;
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
