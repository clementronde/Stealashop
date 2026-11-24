#!/usr/bin/env bash
# a286 : lanceur du banc a09 d'a257 corrigé par ../../patches/a09.sed (TrapSlip au contrat : 26 animations). Arbre sans
# TrapSlip au contrat : le lanceur d'a257, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q '"TrapSlip"' "$REPO/src/shared/Contract/Animations.luau" 2>/dev/null; then
	exec bash "$H/a257-banc/autres-bancs/a09/run.sh" "$@"
fi
exec bash "$H/a286-banc/corrige.sh" a09 bash "$H/a257-banc/autres-bancs/a09/run.sh" "$@"
