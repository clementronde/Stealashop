#!/usr/bin/env bash
# a278 (23/11) : le banc a285 tel que le lance a298 (a298-banc/autres-bancs/a285/run.sh), puis ../../patches/a285.sed
# (Spring codé : U1). Arbre sans a278 (pas de HoverGrow dans Config/UiMotion) : le lanceur d'a298 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "HoverGrow = {" "$REPO/src/shared/Config/UiMotion.luau" 2>/dev/null; then
	exec bash "$H/a298-banc/autres-bancs/a285/run.sh" "$@"
fi
exec bash "$H/a278-banc/corrige.sh" a285 bash "$H/a298-banc/autres-bancs/a285/run.sh" "$@"
