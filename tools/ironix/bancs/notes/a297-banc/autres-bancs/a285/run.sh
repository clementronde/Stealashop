#!/usr/bin/env bash
# a297 (21/11) : le banc a285 corrigé par a294 (a294-banc/autres-bancs/a285/run.sh), puis par ../../patches/a285.sed (reçus
# du crochet « STUDIO-<GUID du Play>-n » ; scénarios crate et hook sans ouverture : messages tout de suite ; flush avant de
# compter les messages). Arbre sans a297 (pas de testSession dans MonetizationService) : le lanceur d'a294 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'local testSession: string? = nil' "$REPO/src/server/Services/MonetizationService.luau" 2>/dev/null; then
	exec bash "$H/a294-banc/autres-bancs/a285/run.sh" "$@"
fi
exec bash "$H/a297-banc/corrige.sh" a285 bash "$H/a294-banc/autres-bancs/a285/run.sh" "$@"
