#!/usr/bin/env bash
# a238 (vague 71, L-213 point 3a) : lanceur du banc a56. Index trié par rareté (byRarity dans IndexController) :
# le lanceur d'a67 enveloppé par ../../corrige.sh (patches/a56.sed : ordre attendu des cartes) ; avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "local function byRarity" "$REPO/src/client/Controllers/IndexController.luau" 2>/dev/null; then
	exec bash "$H/a238-banc/corrige.sh" a56 bash "$H/a67-banc/autres-bancs/a56-banc/run.sh" "$@"
fi
exec bash "$H/a67-banc/autres-bancs/a56-banc/run.sh" "$@"
