#!/usr/bin/env bash
# a251 (vague 73, L-246) : lanceur du banc a170 corrigé par ../../patches/a170.sed (UI_Unbox revient au contrat : écran
# facultatif avec EdgeGlow, plus dans UI.Retired). Arbre sans a251 (pas de Shared/UnboxPlan) : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/UnboxPlan.luau" ]; then
	exec bash "$H/a170-banc/run.sh" "$@"
fi
exec bash "$H/a251-banc/corrige.sh" a170 bash "$H/a170-banc/run.sh" "$@"
