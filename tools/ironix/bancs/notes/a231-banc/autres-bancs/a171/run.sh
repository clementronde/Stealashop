#!/usr/bin/env bash
# a231 (vague 70) : banc a171 par ../../corrige.sh (patches/a171.sed : journaux du vigile « objet » au lieu de « colis »).
# Arbre sans followOwner dans GuardService (avant a231) : le lanceur d'avant (a218-banc/autres-bancs/a171) tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "followOwner" "$REPO/src/server/Services/GuardService.luau" 2>/dev/null; then
	exec bash "$H/a218-banc/autres-bancs/a171/run.sh" "$@"
fi
exec bash "$H/a231-banc/corrige.sh" a171 bash "$H/a218-banc/autres-bancs/a171/run.sh" "$ARG"
