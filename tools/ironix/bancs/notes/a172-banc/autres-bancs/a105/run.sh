#!/usr/bin/env bash
# a172 (2026-11-15, vague 53) : lanceur du banc a105 ($H/a158-banc/autres-bancs/a105/run.sh) avec les correctifs d'a172-banc/patches/a105.sed : plus de Features.ShelfOpen.
# Arbre avec Features.ShelfOpen : le banc tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "ShelfOpen = true" "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a158-banc/autres-bancs/a105/run.sh" "$@"
fi
exec bash "$H/a172-banc/corrige.sh" a105 bash "$H/a158-banc/autres-bancs/a105/run.sh" "$@"
