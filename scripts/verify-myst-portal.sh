#!/bin/bash
# Verifica che myst in esecuzione sia il binario edit-portal aggiornato.
set -euo pipefail
cd "$(dirname "$0")/.."

API_SECRET="${EDIT_API_SECRET:-nebbie-edit-dev-secret}"
API_PORT="${EDIT_API_PORT:-8090}"

fail() {
	echo "ERRORE: $*" >&2
	exit 1
}

bin_has_marker() {
	local f="$1"
	grep -aq portal_api_version "$f" 2>/dev/null || strings "$f" 2>/dev/null | grep -q portal_api_version
}

echo "=== sorgente ==="
if grep -qE 'portal_api_version|kEditPortalApiVersion' src/edit_portal.cpp src/edit_portal.hpp 2>/dev/null; then
	echo "OK: edit_portal espone portal_api_version"
else
	fail "src/edit_portal.cpp/.hpp vecchio — git pull/merge feature/edit-portal"
fi

echo ""
echo "=== binari su disco ==="
for f in mudroot/myst build/src/myst; do
	if [ -f "$f" ]; then
		echo "$f: $(ls -la "$f" | awk '{print $5, $6, $7, $8}')"
		if bin_has_marker "$f"; then
			echo "  -> marker portal_api_version: SI"
		else
			echo "  -> marker portal_api_version: NO — ricompila: docker compose run --rm --entrypoint '' mudcompiler ./build.sh devel" >&2
		fi
	else
		echo "$f: non presente"
	fi
done

echo ""
echo "=== MD5 host vs container ==="
if [ -f mudroot/myst ] && docker ps --format '{{.Names}}' | grep -qx mudcompiler; then
	H="$(md5sum mudroot/myst | awk '{print $1}')"
	C="$(docker exec mudcompiler md5sum /app/mudroot/myst 2>/dev/null | awk '{print $1}' || true)"
	echo "host:      $H"
	echo "container: ${C:-n/a}"
	if [ -n "$C" ] && [ "$H" != "$C" ]; then
		echo "" >&2
		fail "MD5 diverso: il container mudcompiler NON vede il myst appena compilato." >&2
		echo "  Il bind mount è stato fissato alla creazione del container (path vecchio)." >&2
		echo "  Fix: docker rm -f mudcompiler && ./scripts/mud-dev.sh rebuild-myst" >&2
	fi
	MOUNT="$(docker inspect mudcompiler --format '{{range .Mounts}}{{if eq .Destination \"/app\"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || true)"
	echo "mount /app: ${MOUNT:-?}"
fi

echo ""
echo "=== container mudcompiler ==="
if ! docker ps --format '{{.Names}}' | grep -qx mudcompiler; then
	fail "container mudcompiler non in esecuzione"
fi
docker exec mudcompiler bash -c 'ls -la /app/mudroot/myst; pgrep -a myst || true'

echo ""
echo "=== ping API (host :${API_PORT}) — test principale ==="
PING_JSON="$(curl -sf -X POST "http://localhost:${API_PORT}/internal/ping" \
	-H "X-Edit-Api-Secret: ${API_SECRET}" \
	-H "Content-Type: application/json" -d '{}' || true)"
if [ -z "$PING_JSON" ]; then
	fail "ping su :${API_PORT} fallito"
fi
echo "$PING_JSON" | python3 -m json.tool
if ! echo "$PING_JSON" | grep -q portal_api_version; then
	echo "" >&2
	fail "myst in esecuzione è VECCHIO (no portal_api_version nella risposta). Esegui:" >&2
	echo "  docker compose run --rm --entrypoint '' mudcompiler ./build.sh devel" >&2
	echo "  ./scripts/mud-dev.sh stop-mud" >&2
	echo "  ./scripts/mud-dev.sh start-mud" >&2
	echo "  oppure: docker compose stop mudcompiler && docker compose rm -f mudcompiler && docker compose up -d mudcompiler" >&2
fi

echo ""
echo "=== ping via edit-portal :${EDIT_WEB_PORT:-3080} ==="
EDIT_PORT="${EDIT_WEB_PORT:-3080}"
HEALTH_JSON="$(curl -sf "http://localhost:${EDIT_PORT}/api/health" || true)"
if [ -z "$HEALTH_JSON" ]; then
	echo "(edit-portal non risponde su :${EDIT_PORT})"
else
	echo "$HEALTH_JSON" | python3 -m json.tool
fi

echo ""
echo "=== UI build (edit-portal) ==="
UI_BUILD_API="$(echo "$HEALTH_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("ui_build",""))' 2>/dev/null || true)"
IN_CONTAINER=""
if docker exec nebbie-edit-portal grep -q 'EDIT_PORTAL_UI_BUILD = 8' /app/public/app.js 2>/dev/null; then
	IN_CONTAINER="yes"
fi
UI_JS_HEAD="$(curl -sf "http://localhost:${EDIT_PORT}/app.js" 2>/dev/null | head -n 15 || true)"
echo "  /api/health ui_build: ${UI_BUILD_API:-?}"
echo "  container app.js marker: ${IN_CONTAINER:-no}"
if [ -n "$UI_JS_HEAD" ]; then
	echo "  curl /app.js (prime righe):"
	echo "$UI_JS_HEAD" | sed 's/^/    /'
fi
if [ "$UI_BUILD_API" = "8" ] && [ "$IN_CONTAINER" = "yes" ]; then
	echo "OK: edit-portal UI build 8"
else
	echo "" >&2
	echo "ERRORE: edit-portal non serve UI build 8." >&2
	echo "  Fix: ./scripts/mud-dev.sh start-edit" >&2
	echo "  Poi: docker exec nebbie-edit-portal head -n 12 /app/public/app.js" >&2
	exit 1
fi

echo ""
echo "OK: myst edit-portal API aggiornata."
