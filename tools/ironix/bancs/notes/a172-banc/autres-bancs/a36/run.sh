#!/usr/bin/env bash
# a172 (2026-11-15, vague 53) : lanceur du banc a36 (celui d'a158, a158-banc/autres-bancs/a36), avec en plus les correctifs
# d'a172-banc/patches/a36.sed (section C4, voir ce fichier). Arbre avec Features.ShelfOpen : le lanceur d'a158 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "ShelfOpen = true" "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a158-banc/autres-bancs/a36/run.sh" "$@"
fi
exec bash "$H/a172-banc/corrige.sh" a36 bash "$H/a158-banc/autres-bancs/a36/run.sh" "$@"
