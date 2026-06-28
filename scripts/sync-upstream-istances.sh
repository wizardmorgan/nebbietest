#!/usr/bin/env bash
# Sincronizza feature/istances2.0 dal repo ufficiale NebbieArcane/Server
# verso il fork wizardmorgan/nebbietest, mantenendo le patch locali (es. Docker).
#
# Convenzione remote su nucbuntu (NON rinominare senza motivo):
#   origin  -> https://github.com/NebbieArcane/Server.git   (ufficiale)
#   mine    -> https://github.com/wizardmorgan/nebbietest.git (fork)
#
# Uso:
#   cd /home/nebbie/docker-vms/Server
#   ./scripts/sync-upstream-istances.sh          # merge
#   ./scripts/sync-upstream-istances.sh --rebase # rebase (storia lineare)

set -euo pipefail

BRANCH="feature/istances2.0"
REBASE=0
if [[ "${1:-}" == "--rebase" ]]; then
  REBASE=1
fi

die() { echo "ERRORE: $*" >&2; exit 1; }

[[ -d .git ]] || die "esegui dalla root del clone git (es. /home/nebbie/docker-vms/Server)"

echo "=== Verifica remote ==="
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
MINE_URL="$(git remote get-url mine 2>/dev/null || true)"
echo "origin: ${ORIGIN_URL:-MANCANTE}"
echo "mine:   ${MINE_URL:-MANCANTE}"

[[ "$ORIGIN_URL" == *NebbieArcane/Server* ]] || die "remote 'origin' deve puntare a NebbieArcane/Server"
[[ "$MINE_URL" == *wizardmorgan/nebbietest* ]] || die "remote 'mine' deve puntare a wizardmorgan/nebbietest"

echo "=== Fetch ==="
git fetch origin --prune
git fetch mine --prune

CURRENT="$(git branch --show-current)"
[[ "$CURRENT" == "$BRANCH" ]] || die "checkout su $BRANCH prima di sincronizzare (ora: $CURRENT)"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ATTENZIONE: working tree non pulito:"
  git status -sb
  die "committa, stash o ripristina le modifiche locali prima del sync"
fi

UPSTREAM_REF="origin/$BRANCH"
FORK_REF="mine/$BRANCH"

git show-ref --verify --quiet "refs/remotes/$UPSTREAM_REF" || die "manca $UPSTREAM_REF (fetch origin fallito?)"
git show-ref --verify --quiet "refs/remotes/$FORK_REF" || echo "AVVISO: $FORK_REF non trovato (primo push?)"

BEHIND="$(git rev-list --count HEAD.."$UPSTREAM_REF" 2>/dev/null || echo 0)"
AHEAD="$(git rev-list --count "$UPSTREAM_REF"..HEAD 2>/dev/null || echo 0)"
echo "=== Stato vs ufficiale ($UPSTREAM_REF) ==="
echo "commit locali non su ufficiale: $AHEAD"
echo "commit ufficiale non in locale:   $BEHIND"
if [[ "$BEHIND" -gt 0 ]]; then
  echo "--- novità upstream ---"
  git log --oneline HEAD.."$UPSTREAM_REF" | head -10
fi

if [[ "$BEHIND" -eq 0 ]]; then
  echo "Già allineato con $UPSTREAM_REF."
else
  if [[ "$REBASE" -eq 1 ]]; then
    echo "=== Rebase su $UPSTREAM_REF ==="
    git rebase "$UPSTREAM_REF"
  else
    echo "=== Merge $UPSTREAM_REF ==="
    git merge --no-edit "$UPSTREAM_REF" -m "sync: merge $UPSTREAM_REF into $BRANCH"
  fi
fi

echo "=== Push fork (mine) ==="
git push mine "$BRANCH"

echo "=== Fatto ==="
git log --oneline -5
echo ""
echo "Prossimo passo: ricompila/riavvia stack Docker se necessario (docker-run.sh)."
