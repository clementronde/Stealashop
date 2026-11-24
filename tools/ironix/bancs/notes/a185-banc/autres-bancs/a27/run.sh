#!/usr/bin/env bash
# a185 (2026-11-15, vague 58, L-170 Q2) : lanceur du banc a27 ($H/a158-banc/autres-bancs/a27/run.sh) avec le correctif a185-banc/patches/a27.sed
# (texte V0 changé : « grab the items! » et « … is UNLOCKED! Take your item! »). Arbre sans le nouveau texte : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -qF "grab the items!" "$REPO/src/shared/Config/TruckEvent.luau" 2>/dev/null; then
	exec bash "$H/a158-banc/autres-bancs/a27/run.sh" "$@"
fi
exec bash "$H/a185-banc/corrige.sh" a27 bash "$H/a158-banc/autres-bancs/a27/run.sh" "$@"
