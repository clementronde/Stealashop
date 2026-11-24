#!/usr/bin/env bash
# a297 (21/11) : le banc a171 d'a286 (a286-banc/autres-bancs/a171/run.sh) corrigé par ../../patches/a171.sed (scénario
# a38/studio : reçu du crochet « STUDIO-<GUID du Play>-n »). Arbre sans a297 (pas de testSession) : le lanceur d'a286 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'local testSession: string? = nil' "$REPO/src/server/Services/MonetizationService.luau" 2>/dev/null; then
	exec bash "$H/a286-banc/autres-bancs/a171/run.sh" "$@"
fi
exec bash "$H/a297-banc/corrige.sh" a171 bash "$H/a286-banc/autres-bancs/a171/run.sh" "$@"
