#!/usr/bin/env bash
# a216 (vague 65) : lanceur du banc a208 corrigé par ../../patches/a208.sed (cartes de la v2 gardées écran fermé).
# Arbre sans « decalTextures » dans RobuxShopController (avant la fusion d'a216) : le banc a208 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'decalTextures' "$REPO/src/client/Controllers/RobuxShopController.luau" 2>/dev/null; then
	exec bash "$H/a208-banc/run.sh" "$@"
fi
exec bash "$H/a216-banc/corrige.sh" a208 bash "$H/a208-banc/run.sh" "$@"
