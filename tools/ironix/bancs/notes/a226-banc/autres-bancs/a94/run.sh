#!/usr/bin/env bash
# a226 (vague 68) : banc a94 (panneaux StoreReqSign) avec « Strength 2M ×2 players » et la couleur d'équipe de la dernière
# zone (banc.sh et tests.luau, copie de a134-banc/autres-bancs/a94), lancé comme a198 le lançait (../../../a198-banc/echelle1.sh).
# Arbre sans a226 (pas de teamSuffix dans AdvicePanel) : le lanceur d'avant (a198-banc/autres-bancs/a94/run.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
if ! grep -q "teamSuffix" "${ARG%/src}/src/shared/AdvicePanel.luau" 2>/dev/null; then
	exec bash "$H/a198-banc/autres-bancs/a94/run.sh" "$@"
fi
exec bash "$H/a198-banc/echelle1.sh" "$(cd "$(dirname "$0")" && pwd)/banc.sh" repo "${ARG%/src}"
