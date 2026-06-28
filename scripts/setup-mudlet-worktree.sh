#!/usr/bin/env bash
# Crea (o ripara) un git worktree per il branch mudlet.
#
# Uso (da /home/nebbie/docker-vms/Server):
#   ./scripts/setup-mudlet-worktree.sh
#   cd ../nebbietest-mudlet && git status   # deve dire: On branch mudlet

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

REMOTE_REF="$REMOTE/$BRANCH"
git show-ref --verify --quiet "refs/remotes/$REMOTE_REF" \
  || { echo "ERRORE: manca $REMOTE_REF — fetch fallito?" >&2; exit 1; }

repair_detached() {
  local path="$1"
  echo "Riparo worktree in detached HEAD: $path"
  git -C "$path" checkout -B "$BRANCH" "$REMOTE_REF"
  git -C "$path" branch --set-upstream-to="$REMOTE_REF" "$BRANCH"
  git -C "$path" status -sb
}

if [[ -d "$WORKTREE_PATH" ]]; then
  if git -C "$WORKTREE_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CURRENT="$(git -C "$WORKTREE_PATH" symbolic-ref -q HEAD || echo DETACHED)"
    if [[ "$CURRENT" == "refs/heads/$BRANCH" ]]; then
      echo "Worktree ok: $WORKTREE_PATH (branch $BRANCH)"
      git -C "$WORKTREE_PATH" status -sb
      exit 0
    fi
    repair_detached "$WORKTREE_PATH"
    exit 0
  fi
  echo "ERRORE: $WORKTREE_PATH esiste ma non è un worktree git" >&2
  exit 1
fi

mkdir -p "$(dirname "$WORKTREE_PATH")"
# -B: crea branch locale 'mudlet' che punta a mine/mudlet (NON detached HEAD)
git worktree add -B "$BRANCH" "$WORKTREE_PATH" "$REMOTE_REF"
git -C "$WORKTREE_PATH" branch --set-upstream-to="$REMOTE_REF" "$BRANCH"

echo ""
echo "Worktree mudlet creato:"
echo "  cd $WORKTREE_PATH"
git -C "$WORKTREE_PATH" status -sb
