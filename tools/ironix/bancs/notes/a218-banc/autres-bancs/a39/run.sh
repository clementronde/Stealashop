#!/usr/bin/env bash
# a218 (vague 66, L-210 point 1) : lanceur du banc a39 corrigé par ../../patches/a39.sed (offre à l'Id 0 ou pas codée :
# « Soon » en permanence ; chances V0 de la caisse). Arbre sans « notForSale » dans RobuxShopController : le lanceur d'avant.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'notForSale' "$REPO/src/client/Controllers/RobuxShopController.luau" 2>/dev/null; then
	exec bash "$H/a208-banc/autres-bancs/a39/run.sh" "$@"
fi
exec bash "$H/a218-banc/corrige.sh" a39 bash "$H/a208-banc/autres-bancs/a39/run.sh" "$@"
