#!/usr/bin/env bash
# a298 (21/11) : le banc a285 corrigé par a297 (a297-banc/autres-bancs/a285/run.sh), puis par ../../patches/a285.sed
# (Gleam sur un texte ignoré : U1, U3 et U9). Arbre sans a298 (pas d'UI/FramewispFx) : le lanceur d'a297 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/client/Controllers/UI/FramewispFx.luau" ]; then
	exec bash "$H/a297-banc/autres-bancs/a285/run.sh" "$@"
fi
exec bash "$H/a298-banc/corrige.sh" a285 bash "$H/a297-banc/autres-bancs/a285/run.sh" "$@"
