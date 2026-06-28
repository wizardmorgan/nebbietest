#!/usr/bin/env bash
# Crea un git worktree per il branch mudlet (package Mudlet) accanto al clone Server.
#
# Cos'è un worktree?
#   Una seconda cartella di lavoro collegata allo STESSO repository .git,
#   ma con un branch diverso checkato (qui: mudlet). Modifiche, commit e push
#   restano nello stesso repo remoto (mine → wizardmorgan/nebbietest).
#
# Uso (da /home/nebbie/docker-vms/Server):
#   ./scripts/setup-mudlet-worktree.sh
#   cd ../nebbietest-mudlet
#   git status
#
# Path default worktree: ../nebbietest-mudlet (sibling di Server)

set -euo pipefail

BRANCH="mudlet"
REMOTE="mine"
DEFAULT_PATH="$(cd "$(dirname "$0")/.." && pwd)/../nebbietest-mudlet"
WORKTREE_PATH="${1:-$DEFAULT_PATH}"

[[ -d .git ]] || { echo "ERRORE: esegui dalla root del clone Server" >&2; exit 1; }

if git remote get-url "$REMOTE" >/dev/null 2>&1; then
  git fetch "$REMOTE" "$BRANCH" --prune
else
  echo "AVVISO: remote '$REMOTE' non trovato; uso fetch --all"
  git fetch --all --prune
fi

if [[ -d "$WORKTREE_PATH" ]]; then
  if git -C "$WORKTREE_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Worktree già presente: $WORKTREE_PATH"
    git -C "$WORKTREE_PATH" status -sb
    exit 0
  fi
  echo "ERRORE: $WORKTREE_PATH esiste ma non è un worktree git" >&2
  exit 1
fi

mkdir -p "$(dirname "$WORKTREE_PATH")"
git worktree add "$WORKTREE_PATH" "$REMOTE/$BRANCH" 2>/dev/null \
  || git worktree add "$WORKTREE_PATH" "$BRANCH"

echo ""
echo "Worktree mudlet creato:"
echo "  cd $WORKTREE_PATH"
echo "  # lavori su docs/mudlet/, poi:"
echo "  git add ... && git commit -m '...' && git push $REMOTE $BRANCH"
