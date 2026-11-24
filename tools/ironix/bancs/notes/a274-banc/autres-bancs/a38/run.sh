#!/usr/bin/env bash
# a274 (vague GC2, H1) : lanceur du banc a38. Arbre avec la fin d'achat confirmée par Roblox (verifyPurchase dans
# MonetizationService) : la copie a158 corrigée par ../../corrige.sh (patches/a38.pl : scénario « passes », cas H1a
# à H1h). Arbre sans a274 : la copie a158 telle quelle.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "verifyPurchase" "$REPO/src/server/Services/MonetizationService.luau" 2>/dev/null; then
	exec bash "$H/a158-banc/autres-bancs/a38/run.sh" "$@"
fi
exec bash "$H/a274-banc/corrige.sh" a38 bash "$H/a158-banc/autres-bancs/a38/run.sh" "$@"
