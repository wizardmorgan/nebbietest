#!/bin/bash
# Allinea il branch locale a origin/feature/Razze (repo NebbieArcane).
set -euo pipefail
cd "$(dirname "$0")/.."
git fetch origin feature/Razze
git merge --no-edit origin/feature/Razze
echo "Allineato a origin/feature/Razze. Branch attuale: $(git branch --show-current)"
