#!/usr/bin/env bash
# a319 (L-303) : banc a190 via ../../corrige.sh (patches/a190.pl : M1d et M5, x2 SPEED devenu le gamepass DoubleSpeed) ;
# lanceur d'avant : a224-banc/autres-bancs/a190/run.sh. Arbre sans DoubleSpeed (avant a319) : tel quel.
N="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
if ! grep -q 'Key = "DoubleSpeed"' "${ARG%/src}/src/shared/Config/Monetization.luau" 2>/dev/null; then
	exec bash "$N/a224-banc/autres-bancs/a190/run.sh" "$@"
fi
exec bash "$N/a319-banc/corrige.sh" a190 bash "$N/a224-banc/autres-bancs/a190/run.sh" "$@"
