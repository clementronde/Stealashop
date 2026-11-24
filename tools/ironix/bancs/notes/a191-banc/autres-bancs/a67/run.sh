#!/usr/bin/env bash
# a191 (2026-11-15, vague 59, L-183 : récompense de zone de l'Index en valeurs fixes) : lanceur du banc a67.
# Avant a191 (pas de ZoneRewards dans Config/Index) : le lanceur d'avant (a117-banc/autres-bancs/a67-banc/run.sh), tel quel.
# Depuis a191 : ../../corrige.sh (patches/index.sed et patches/a67.sed s'il existe) autour du même lanceur.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "ZoneRewards = ZONE_REWARDS" "$REPO/src/shared/Config/Index.luau" 2>/dev/null; then
	exec bash "$H/a117-banc/autres-bancs/a67-banc/run.sh" "$@"
fi
exec bash "$H/a191-banc/corrige.sh" a67 bash "$H/a117-banc/autres-bancs/a67-banc/run.sh" "$@"
