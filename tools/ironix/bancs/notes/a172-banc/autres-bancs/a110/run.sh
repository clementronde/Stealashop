#!/usr/bin/env bash
# a172 (2026-11-15, vague 53) : copie de lanceur d'a134-banc/autres-bancs/a110, lancé avec le seul scénario « exit » :
# « oldflow » (Features.ShelfOpen forcé à false, pre.oldflow.luau) n'a plus d'objet, l'interrupteur est parti.
# Arbre avec Features.ShelfOpen : le banc tel quel (exit et oldflow).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
if grep -q "ShelfOpen = true" "$ROOT/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a134-banc/autres-bancs/a110/run.sh" "$@"
fi
exec bash "$H/a134-banc/autres-bancs/a110/run.sh" "$ROOT" exit
