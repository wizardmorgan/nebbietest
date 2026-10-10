#!/usr/bin/env bash
# Pubblica il Mudlet dashboard su wizardmorgan/nebbie-mudlet-dashboard (branch main).
# Eseguire dopo build-nebbie-complete-dashboard-package.py in docs/mudlet/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/docs/mudlet"

# Git isolato: evita rewrite Cursor (cursor[bot]) e insteadOf globali.
GIT_PUBLISH_CONFIG="${TMPDIR:-/tmp}/nebbie-mudlet-dashboard-gitconfig"
printf '[user]\n\temail = nebbie-mudlet-dashboard@wizardmorgan.github\n\tname = Nebbie Mudlet Dashboard Release\n' > "${GIT_PUBLISH_CONFIG}"
export GIT_CONFIG_GLOBAL="${GIT_PUBLISH_CONFIG}"
export GIT_CONFIG_SYSTEM=/dev/null
git_publish() {
  git -c credential.helper= "$@"
}

verify_write_access() {
  local pat="${1:-}"
  if [[ -z "${pat}" ]]; then
    return 0
  fi
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
    -H "Authorization: Bearer ${pat}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/wizardmorgan/nebbie-mudlet-dashboard/contents/.publish-auth-probe" \
    -d "{\"message\":\"auth probe\",\"content\":\"$(echo -n x | base64 -w0)\"}")"
  if [[ "${code}" == "200" || "${code}" == "201" ]]; then
    echo "==> PAT: permesso scrittura Contents OK (probe ${code})"
    return 0
  fi
  echo "ERRORE: PAT senza permesso Contents: write su nebbie-mudlet-dashboard (HTTP ${code})." >&2
  echo "Rigenera il fine-grained PAT con Contents Read and write solo su quel repo," >&2
  echo "oppure imposta WIZARDMORGAN_GITHUB_SSH_KEY (deploy key con write)." >&2
  return 1
}

SSH_KEY_MATERIAL="${WIZARDMORGAN_GITHUB_SSH_KEY:-${NEBBIE_MUDLET_DASHBOARD_SSH_KEY:-}}"
SSH_KEY_FILE=""
if [[ -n "${SSH_KEY_MATERIAL}" ]]; then
  SSH_KEY_FILE="${TMPDIR:-/tmp}/nebbie-mudlet-dashboard-ssh-key"
  printf '%s\n' "${SSH_KEY_MATERIAL}" > "${SSH_KEY_FILE}"
  chmod 600 "${SSH_KEY_FILE}"
  export GIT_SSH_COMMAND="ssh -i ${SSH_KEY_FILE} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  DEST_REPO="git@github.com:wizardmorgan/nebbie-mudlet-dashboard.git"
  # Cursor Cloud riscrive git@github.com → HTTPS cursor[bot]: serve HOME pulito per SSH reale.
  export GIT_PUBLISH_HOME="${TMPDIR:-/tmp}/nebbie-mudlet-dashboard-git-home"
  rm -rf "${GIT_PUBLISH_HOME}"
  mkdir -p "${GIT_PUBLISH_HOME}"
  export HOME="${GIT_PUBLISH_HOME}"
else
  PAT="${NEBBIE_MUDLET_DASHBOARD_PAT:-${WIZARDMORGAN_GITHUB_PAT:-}}"
  if [[ -n "${PAT}" ]]; then
    verify_write_access "${PAT}"
    DEST_REPO="https://x-access-token:${PAT}@github.com/wizardmorgan/nebbie-mudlet-dashboard.git"
    export GIT_PUBLISH_HOME="${TMPDIR:-/tmp}/nebbie-mudlet-dashboard-git-home-pat"
    rm -rf "${GIT_PUBLISH_HOME}"
    mkdir -p "${GIT_PUBLISH_HOME}"
    export HOME="${GIT_PUBLISH_HOME}"
  else
    DEST_REPO="${NEBBIE_MUDLET_DASHBOARD_REPO:-git@github.com:wizardmorgan/nebbie-mudlet-dashboard.git}"
    export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o StrictHostKeyChecking=accept-new}"
  fi
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
if [[ -n "${SSH_KEY_FILE}" ]]; then
  env GIT_SSH_COMMAND="${GIT_SSH_COMMAND}" git_publish clone --depth 1 --branch main "${DEST_REPO}" "${WORKDIR}"
else
  git_publish clone --depth 1 --branch main "${DEST_REPO}" "${WORKDIR}"
fi

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
git remote set-url origin "${DEST_REPO}"
if git diff --quiet && git diff --cached --quiet; then
  echo "Nessuna modifica da pubblicare."
  exit 0
fi
VER="$(rg -m1 'local PKG_VER = \"([^\"]+)\"' nebbie-complete-dashboard-package-core.lua -o -r '$1' || true)"
git add -A
git_publish commit -m "release: nebbie-complete-dashboard-package ${VER:-unknown}"

echo "==> Push main"
if [[ -n "${SSH_KEY_FILE}" ]]; then
  if ! env -u GIT_ASKPASS GIT_SSH_COMMAND="${GIT_SSH_COMMAND}" git -c credential.helper= push origin main; then
    PUSH_FAILED=1
  fi
else
  if ! git_publish push origin main; then
    PUSH_FAILED=1
  fi
fi
if [[ -n "${PUSH_FAILED:-}" ]]; then
  echo "ERRORE: push su wizardmorgan/nebbie-mudlet-dashboard fallito." >&2
  if [[ -n "${SSH_KEY_FILE}" ]]; then
    echo "La chiave SSH deve essere registrata su GitHub per l'account wizardmorgan (write su questo repo)." >&2
    echo "Secret consigliato: WIZARDMORGAN_GITHUB_SSH_KEY (non EDIT_PORTAL_SSH_KEY / deploy key altri repo)." >&2
  else
    echo "Usa WIZARDMORGAN_GITHUB_SSH_KEY oppure PAT con permesso push (Contents: write)." >&2
  fi
  exit 1
fi

echo "OK: https://github.com/wizardmorgan/nebbie-mudlet-dashboard"
echo "URL: https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage"
