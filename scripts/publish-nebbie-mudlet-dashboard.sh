#!/usr/bin/env bash
# Pubblica il Mudlet dashboard su wizardmorgan/nebbie-mudlet-dashboard (branch main).
# Eseguire dopo build-nebbie-complete-dashboard-package.py in docs/mudlet/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/docs/mudlet"
PAT="${NEBBIE_MUDLET_DASHBOARD_PAT:-${WIZARDMORGAN_GITHUB_PAT:-}}"
if [[ -n "${PAT}" ]]; then
  DEST_REPO="https://x-access-token:${PAT}@github.com/wizardmorgan/nebbie-mudlet-dashboard.git"
else
  DEST_REPO="${NEBBIE_MUDLET_DASHBOARD_REPO:-https://github.com/wizardmorgan/nebbie-mudlet-dashboard.git}"
fi
WORKDIR="${TMPDIR:-/tmp}/nebbie-mudlet-dashboard-publish"

if [[ ! -f "${SRC}/build-nebbie-complete-dashboard-package.py" ]]; then
  echo "Manca ${SRC}/build-nebbie-complete-dashboard-package.py" >&2
  exit 1
fi

echo "==> Build package"
(cd "${SRC}" && python3 build-nebbie-complete-dashboard-package.py)

echo "==> Clone ${DEST_REPO}"
rm -rf "${WORKDIR}"
git clone --depth 1 --branch main "${DEST_REPO}" "${WORKDIR}"

echo "==> Sync sorgenti"
(
  cd "${SRC}"
  tar cf - \
    --exclude='nebbie-complete-dashboard-package-build' \
    --exclude='.git' \
    .
) | (cd "${WORKDIR}" && tar xf -)

echo "==> Commit"
cd "${WORKDIR}"
if git diff --quiet && git diff --cached --quiet; then
  echo "Nessuna modifica da pubblicare."
  exit 0
fi
VER="$(rg -m1 'local PKG_VER = \"([^\"]+)\"' nebbie-complete-dashboard-package-core.lua -o -r '$1' || true)"
git add -A
git commit -m "release: nebbie-complete-dashboard-package ${VER:-unknown}"

echo "==> Push main"
git push origin main

echo "OK: https://github.com/wizardmorgan/nebbie-mudlet-dashboard"
echo "URL: https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage"
