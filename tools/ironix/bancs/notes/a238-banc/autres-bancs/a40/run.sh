#!/usr/bin/env bash
# a238 (vague 71, L-213 point 3a) : lanceur du banc a40. Index trié par rareté (byRarity dans IndexController) :
# le lanceur d'a158 enveloppé par ../../corrige.sh (patches/a40.sed : ordre attendu des cartes) ; avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "local function byRarity" "$REPO/src/client/Controllers/IndexController.luau" 2>/dev/null; then
	exec bash "$H/a238-banc/corrige.sh" a40 bash "$H/a158-banc/autres-bancs/a40/run.sh" "$@"
fi
exec bash "$H/a158-banc/autres-bancs/a40/run.sh" "$@"
