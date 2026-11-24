#!/usr/bin/env bash
# a243 (vague 72) : lanceur du banc a09 corrigé par ../../patches/a09.sed (TrapStuck et TrapNetted au contrat).
# Arbre sans Config/Traps : le lanceur d'avant (a181), tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/Config/Traps.luau" ]; then
	exec bash "$H/a181-banc/autres-bancs/a09/run.sh" "$@"
fi
exec bash "$H/a243-banc/corrige.sh" a09 bash "$H/a181-banc/autres-bancs/a09/run.sh" "$@"
