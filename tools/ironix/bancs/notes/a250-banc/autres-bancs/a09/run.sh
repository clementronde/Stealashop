#!/usr/bin/env bash
# a250b : lanceur du banc a09 corrigé par ../../patches/a09.sed (les 7 Unbox_* de L-237 au contrat), autour de celui d'a243.
# Arbre sans Unbox_Hammer au contrat : le lanceur d'avant (a243), tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q '"Unbox_Hammer"' "$REPO/src/shared/Contract/Animations.luau" 2>/dev/null; then
	exec bash "$H/a243-banc/autres-bancs/a09/run.sh" "$@"
fi
exec bash "$H/a250-banc/corrige.sh" a09 bash "$H/a243-banc/autres-bancs/a09/run.sh" "$@"
