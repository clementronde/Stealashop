#!/usr/bin/env bash
# a309 : lanceur du banc a303 (a303-banc/run.sh) corrigé par ../../patches/a303.sed (textes des paliers de 15 et 60 min).
# Arbre sans a309 (pas de src/shared/ZoneBoxOdds.luau) : le banc a303, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/ZoneBoxOdds.luau" ]; then
	exec bash "$H/a303-banc/run.sh" "$@"
fi
exec bash "$H/a309-banc/corrige.sh" a303 bash "$H/a303-banc/run.sh" "$@"
