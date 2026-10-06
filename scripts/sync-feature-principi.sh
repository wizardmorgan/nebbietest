#!/bin/bash
# Allinea il branch locale a upstream/feature/Principi (repo NebbieArcane/Server).
set -euo pipefail
cd "$(dirname "$0")/.."
if ! git remote get-url upstream >/dev/null 2>&1; then
	git remote add upstream https://github.com/NebbieArcane/Server.git
fi
git fetch upstream feature/Principi
git merge --no-edit upstream/feature/Principi
echo "Allineato a upstream/feature/Principi. Branch attuale: $(git branch --show-current)"
