#!/usr/bin/env bash
# a185 (2026-11-15, vague 58, L-170 Q2) : lanceur du banc a105 ($H/a172-banc/autres-bancs/a105/run.sh) avec le correctif a185-banc/patches/a105.sed
# (texte V0 changé : « grab the items! » et « … is UNLOCKED! Take your item! »). Arbre sans le nouveau texte : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -qF "UNLOCKED! Take your item!" "$REPO/src/server/Services/UnboxService.luau" 2>/dev/null; then
	exec bash "$H/a172-banc/autres-bancs/a105/run.sh" "$@"
fi
exec bash "$H/a185-banc/corrige.sh" a105 bash "$H/a172-banc/autres-bancs/a105/run.sh" "$@"
