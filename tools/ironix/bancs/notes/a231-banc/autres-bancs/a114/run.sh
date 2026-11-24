#!/usr/bin/env bash
# a231 (vague 70) : banc a114 par ../../corrige.sh (patches/a114.sed : journaux du vigile « objet » au lieu de « colis »).
# Arbre sans followOwner dans GuardService (avant a231) : le lanceur d'avant (a202-banc/autres-bancs/a114) tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "followOwner" "$REPO/src/server/Services/GuardService.luau" 2>/dev/null; then
	exec bash "$H/a202-banc/autres-bancs/a114/run.sh" "$@"
fi
exec bash "$H/a231-banc/corrige.sh" a114 bash "$H/a202-banc/autres-bancs/a114/run.sh" "$ARG"
