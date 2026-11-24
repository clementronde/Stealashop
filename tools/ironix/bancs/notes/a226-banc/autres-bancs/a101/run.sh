#!/usr/bin/env bash
# a226 (vague 68) : banc a101 (bandeau de zone) avec « Damage 2M ×2 players » et la couleur d'équipe de la dernière zone
# (banc.sh et tests.*.luau, copie de a134-banc/autres-bancs/a101). Arbre sans a226 (pas de teamSuffix dans
# AdvicePanel) : le lanceur d'avant (a134-banc/autres-bancs/a101/run.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
if ! grep -q "teamSuffix" "${ARG%/src}/src/shared/AdvicePanel.luau" 2>/dev/null; then
	exec bash "$H/a134-banc/autres-bancs/a101/run.sh" "$@"
fi
exec bash "$(cd "$(dirname "$0")" && pwd)/banc.sh" "$@"
