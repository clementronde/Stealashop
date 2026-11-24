#!/usr/bin/env bash
# fusion53 (2026-11-15, vague 59) : lanceur du banc a48 corrigé par ../../patches/a48.sed (voir ce fichier).
# Arbre d'avant a191 (pas de ZoneRewards dans Config/Index) : le lanceur d'avant (a158-banc/autres-bancs/a48/run.sh), tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "ZoneRewards = ZONE_REWARDS" "$REPO/src/shared/Config/Index.luau" 2>/dev/null; then
	exec bash "$H/a158-banc/autres-bancs/a48/run.sh" "$@"
fi
exec bash "$H/f53-banc/corrige.sh" a48 bash "$H/a158-banc/autres-bancs/a48/run.sh" "$@"
