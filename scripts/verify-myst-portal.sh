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
if grep -q 'portal_api_version' src/edit_portal.cpp 2>/dev/null; then
	echo "OK: src/edit_portal.cpp contiene portal_api_version"
else
	fail "src/edit_portal.cpp vecchio — git pull/merge feature/edit-portal"
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
echo "=== ping via edit-portal :3080 ==="
curl -sf "http://localhost:3080/api/health" | python3 -m json.tool || echo "(edit-portal non risponde)"

echo ""
echo "OK: myst edit-portal API aggiornata."
