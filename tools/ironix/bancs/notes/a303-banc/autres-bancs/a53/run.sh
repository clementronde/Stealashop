#!/usr/bin/env bash
# a303 : lanceur du banc a53 d'avant (a262-banc/autres-bancs/a53/run.sh) corrigé par ../../patches/a53.sed (sans RewardDesc,
# RewardName dit le gain du palier). Arbre sans a303 (pas de RewardDesc dans RewardsController) : la copie d'a262, telle quelle.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "RewardDesc" "$REPO/src/client/Controllers/RewardsController.luau" 2>/dev/null; then
	exec bash "$H/a262-banc/autres-bancs/a53/run.sh" "$@"
fi
exec bash "$H/a303-banc/corrige.sh" a53 bash "$H/a262-banc/autres-bancs/a53/run.sh" "$@"
