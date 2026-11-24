#!/usr/bin/env bash
# a309 : lanceur du banc a53 d'avant (a303-banc/autres-bancs/a53/run.sh) corrigé par ../../patches/a53.sed (15 min :
# scène d'ouverture en zone safe, sans Notify ; 60 min : zone suivante ; texte du palier 60). Arbre sans a309 (pas de
# src/shared/ZoneBoxOdds.luau) : la copie d'a303, telle quelle.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/ZoneBoxOdds.luau" ]; then
	exec bash "$H/a303-banc/autres-bancs/a53/run.sh" "$@"
fi
exec bash "$H/a309-banc/corrige.sh" a53 bash "$H/a303-banc/autres-bancs/a53/run.sh" "$@"
