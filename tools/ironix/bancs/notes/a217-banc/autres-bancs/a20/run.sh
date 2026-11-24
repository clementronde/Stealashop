#!/usr/bin/env bash
# a217 (vague 65) : lanceur du banc a20 (a198-banc/autres-bancs/a20) corrigé par ../../patches/a20.sed (lignes de la boutique
# d'auras gardées écran fermé : K17, Z3 et Z7). Arbre sans « assetTextures » dans AuraShopController : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'assetTextures' "$REPO/src/client/Controllers/AuraShopController.luau" 2>/dev/null; then
	exec bash "$H/a198-banc/autres-bancs/a20/run.sh" "$@"
fi
exec bash "$H/a217-banc/corrige.sh" a20 bash "$H/a198-banc/autres-bancs/a20/run.sh" "$@"
