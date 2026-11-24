#!/usr/bin/env bash
# a206 : run-core.sh à travers a158-banc/corrige.sh (comme le banc a142).   bash run-core-a158.sh <racine> [scénarios…]
H="$(cd "$(dirname "$0")" && pwd)"
exec bash "$H/../a158-banc/corrige.sh" a206 bash "$H/run-core.sh" "$@"
