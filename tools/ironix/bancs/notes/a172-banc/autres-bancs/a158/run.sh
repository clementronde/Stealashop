#!/usr/bin/env bash
# a172 (2026-11-15, vague 53) : lanceur du banc a158 ($H/a169-banc/autres-bancs/a158/run.sh) avec les correctifs d'a172-banc/patches/a158.sed : accroches OnBox* et GetOpenDelay retirées.
# Arbre avec Features.ShelfOpen : le banc tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "ShelfOpen = true" "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a169-banc/autres-bancs/a158/run.sh" "$@"
fi
exec bash "$H/a172-banc/corrige.sh" a158 bash "$H/a169-banc/autres-bancs/a158/run.sh" "$@"
