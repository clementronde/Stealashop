#!/usr/bin/env bash
# a243 (vague 72) : lanceur du banc a39 corrigé par ../../patches/a39.sed (fiche Trap après RobuxShopCounter).
# Arbre sans Config/Traps : le lanceur d'avant (a238), tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/Config/Traps.luau" ]; then
	exec bash "$H/a238-banc/autres-bancs/a39/run.sh" "$@"
fi
exec bash "$H/a243-banc/corrige.sh" a39 bash "$H/a238-banc/autres-bancs/a39/run.sh" "$@"
