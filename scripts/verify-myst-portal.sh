#!/bin/bash
# Verifica che myst in esecuzione sia il binario edit-portal aggiornato.
set -euo pipefail
cd "$(dirname "$0")/.."

API_SECRET="${EDIT_API_SECRET:-nebbie-edit-dev-secret}"
API_PORT="${EDIT_API_PORT:-8090}"

echo "=== sorgente ==="
if grep -q 'portal_api_version' src/edit_portal.cpp 2>/dev/null; then
	echo "OK: src/edit_portal.cpp contiene portal_api_version"
else
	echo "ERRORE: src/edit_portal.cpp vecchio — git pull/merge mine/feature/edit-portal" >&2
	exit 1
fi

echo ""
echo "=== binari su disco ==="
for f in mudroot/myst build/src/myst; do
	if [ -f "$f" ]; then
		echo "$f: $(ls -la "$f" | awk '{print $5, $6, $7, $8}')"
		if strings "$f" 2>/dev/null | grep -q portal_api_version; then
			echo "  -> marker portal_api_version: SI"
		else
			echo "  -> marker portal_api_version: NO (ricompila: ./build.sh devel)" >&2
		fi
	else
		echo "$f: non presente"
	fi
done

echo ""
echo "=== container mudcompiler ==="
if ! docker ps --format '{{.Names}}' | grep -qx mudcompiler; then
	echo "ERRORE: container mudcompiler non in esecuzione" >&2
	exit 1
fi
docker exec mudcompiler bash -c 'ls -la /app/mudroot/myst; pgrep -a myst || true'

echo ""
echo "=== ping API (host :${API_PORT}) ==="
curl -sf -X POST "http://localhost:${API_PORT}/internal/ping" \
	-H "X-Edit-Api-Secret: ${API_SECRET}" \
	-H "Content-Type: application/json" -d '{}' | python3 -m json.tool || {
	echo "ERRORE: ping fallito" >&2
	exit 1
}

echo ""
echo "=== ping via edit-portal :3080 ==="
curl -sf "http://localhost:3080/api/health" | python3 -m json.tool || echo "(edit-portal non risponde)"
