#!/usr/bin/env bash
# a309 : lanceur du banc a266 (a268-banc/autres-bancs/a266/run.sh) corrigé par ../../patches/a266.sed (secteurs BOX et
# RARE BOX : colis de zone, Result vide, Gift - ZoneBox). Arbre sans a309 (pas de src/shared/ZoneBoxOdds.luau) : la
# copie d'a268, telle quelle.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/ZoneBoxOdds.luau" ]; then
	exec bash "$H/a268-banc/autres-bancs/a266/run.sh" "$@"
fi
exec bash "$H/a309-banc/corrige.sh" a266 bash "$H/a268-banc/autres-bancs/a266/run.sh" "$@"
