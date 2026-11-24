#!/usr/bin/env bash
# a172 (2026-11-15, vague 53) : lanceur du banc a39 ($H/a164-banc/autres-bancs/a39-banc/run.sh) avec les correctifs d'a172-banc/patches/a39.sed : textes « No item is waiting ».
# Arbre avec Features.ShelfOpen : le banc tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "ShelfOpen = true" "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a164-banc/autres-bancs/a39-banc/run.sh" "$@"
fi
exec bash "$H/a172-banc/corrige.sh" a39 bash "$H/a164-banc/autres-bancs/a39-banc/run.sh" "$@"
