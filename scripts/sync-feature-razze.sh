#!/bin/bash
# Obsoleto: Razze → produzione. Delega a sync-feature-principi.sh
set -euo pipefail
exec "$(dirname "$0")/sync-feature-principi.sh"
