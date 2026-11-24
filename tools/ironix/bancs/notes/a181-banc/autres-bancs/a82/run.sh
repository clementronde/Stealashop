#!/usr/bin/env bash
# a181 (2026-11-15, vague 56) : lanceur du banc a82 corrigé par ../../patches/a82.sed (voir ce fichier).
# Arbre d'avant a181 (pas de NextZoneChance dans Config/TruckEvent) : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'NextZoneChance' "$REPO/src/shared/Config/TruckEvent.luau" 2>/dev/null; then
	exec bash "$H/a141-banc/autres-bancs/a82-banc/run.sh" "$@"
fi
exec bash "$H/a181-banc/corrige.sh" a82 bash "$H/a141-banc/autres-bancs/a82-banc/run.sh" "$@"
