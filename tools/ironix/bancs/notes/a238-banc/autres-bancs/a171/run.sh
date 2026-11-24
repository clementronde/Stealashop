#!/usr/bin/env bash
# a238 (vague 71, L-213 point 1b) : lanceur du banc a171. Ouvrir maintenant garde son bouton sans colis :
# le lanceur d'a218 enveloppé par ../../corrige.sh (patches/a171.sed) ; avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "NoItemPrice" "$REPO/src/client/Controllers/RobuxShopController.luau" 2>/dev/null; then
	exec bash "$H/a238-banc/corrige.sh" a171 bash "$H/a218-banc/autres-bancs/a171/run.sh" "$@"
fi
exec bash "$H/a218-banc/autres-bancs/a171/run.sh" "$@"
