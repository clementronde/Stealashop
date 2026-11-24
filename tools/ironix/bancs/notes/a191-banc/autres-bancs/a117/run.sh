#!/usr/bin/env bash
# a191 (2026-11-15, vague 59, L-183 : récompense de zone de l'Index en valeurs fixes) : lanceur du banc a117.
# Avant a191 (pas de ZoneRewards dans Config/Index) : le lanceur d'avant (a170-banc/autres-bancs/a117/run.sh), tel quel.
# Depuis a191 : ../../corrige.sh (patches/index.sed et patches/a117.sed s'il existe) autour du même lanceur.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "ZoneRewards = ZONE_REWARDS" "$REPO/src/shared/Config/Index.luau" 2>/dev/null; then
	exec bash "$H/a170-banc/autres-bancs/a117/run.sh" "$@"
fi
exec bash "$H/a191-banc/corrige.sh" a117 bash "$H/a170-banc/autres-bancs/a117/run.sh" "$@"
