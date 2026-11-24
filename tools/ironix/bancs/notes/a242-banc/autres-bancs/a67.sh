#!/usr/bin/env bash
# a242 (vague 72, L-213) : banc a67 (a207-banc/autres-bancs/a67) avec a242-banc/patches/a67.sed : la note de ClaimAllButton
# retiré est permise dans « UI_Index_v3 conforme ». Arbre sans a242 (ClaimAllButton encore au contrat) : le banc tel quel.
N="$(cd "$(dirname "$0")/../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q 'Path = "UnlockedBar.ClaimAllButton"' "$REPO/src/shared/Contract/UI.luau" 2>/dev/null; then
	exec bash "$N/a207-banc/autres-bancs/a67/run.sh" "$@"
fi
exec bash "$N/a242-banc/corrige.sh" a67 bash "$N/a207-banc/autres-bancs/a67/run.sh" "$@"
