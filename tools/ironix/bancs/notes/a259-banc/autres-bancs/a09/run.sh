#!/usr/bin/env bash
# a257 : lanceur du banc a09 corrigé par ../../patches/a09.sed (Unbox_Stomp et Unbox_Slam au contrat), autour de celui
# d'a250. Arbre sans Unbox_Slam au contrat : le lanceur d'avant (a250), tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q '"Unbox_Slam"' "$REPO/src/shared/Contract/Animations.luau" 2>/dev/null; then
	exec bash "$H/a250-banc/autres-bancs/a09/run.sh" "$@"
fi
exec bash "$H/a257-banc/corrige.sh" a09 bash "$H/a250-banc/autres-bancs/a09/run.sh" "$@"
