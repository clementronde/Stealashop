#!/usr/bin/env bash
# a176 (2026-11-15, vague 54, Cantin : plus de coffre-fort) : lance un banc existant avec les correctifs de
# a176-banc/patches/<nom>.sed (appliqués au fichier assemblé, corrige.sh) quand l'arbre n'a plus PvP.VaultSlots ;
# arbre avec PvP.VaultSlots (avant la fusion) : le banc tel quel.
#   bash lanceur.sh <nom> <lanceur du banc> <dépôt>
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"; ORIG="$2"; shift 2
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "VaultSlots" "$REPO/src/shared/Config/PvP.luau" 2>/dev/null; then
	exec bash "$ORIG" "$@"
fi
exec bash "$H/corrige.sh" "$NAME" bash "$ORIG" "$@"
