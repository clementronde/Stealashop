#!/usr/bin/env bash
# a217 (vague 65) : lanceur du banc a78 (a198-banc/autres-bancs/a78) corrigé par ../../patches/a78.sed (lignes de la boutique
# d'auras gardées écran fermé : K17, Z3 et Z7). Arbre sans « assetTextures » dans AuraShopController : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'assetTextures' "$REPO/src/client/Controllers/AuraShopController.luau" 2>/dev/null; then
	exec bash "$H/a198-banc/autres-bancs/a78/run.sh" "$@"
fi
exec bash "$H/a217-banc/corrige.sh" a78 bash "$H/a198-banc/autres-bancs/a78/run.sh" "$@"
