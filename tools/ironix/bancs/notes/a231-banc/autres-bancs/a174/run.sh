#!/usr/bin/env bash
# a231 (vague 70) : banc a174 par ../../corrige.sh (patches/a174.sed : journal du vigile « l'objet de X », « ramassé l'objet »).
# Arbre sans followOwner dans GuardService (avant a231) : le lanceur d'avant (a202-banc/autres-bancs/a174) tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "followOwner" "$REPO/src/server/Services/GuardService.luau" 2>/dev/null; then
	exec bash "$H/a202-banc/autres-bancs/a174/run.sh" "$@"
fi
exec bash "$H/a231-banc/corrige.sh" a174 bash "$H/a202-banc/autres-bancs/a174/run.sh" "$ARG"
