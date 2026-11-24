#!/usr/bin/env bash
# fusion67 (vague 72) : banc a207 par ../../corrige.sh (patches/a207.sed : la note de ClaimAllButton retiré par a242 est
# permise dans « UI_Index_v3 refait : aucune ligne » et « écran d avant : aucun problème », aucune autre ligne).
# Arbre sans a242 (ClaimAllButton encore au contrat) : le banc tel quel.
N="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q 'Path = "UnlockedBar.ClaimAllButton"' "$REPO/src/shared/Contract/UI.luau" 2>/dev/null; then
	exec bash "$N/a207-banc/run.sh" "$@"
fi
exec bash "$N/f67-banc/corrige.sh" a207 bash "$N/a207-banc/run.sh" "$@"
