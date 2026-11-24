#!/usr/bin/env bash
# a232 (vague 70) : banc a224 avec le faux Roblox d a232 pour le scénario gain ; arbre sans a232 (pas de NBSP dans
# GainController) : le lanceur d avant (a224-banc/run.sh).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "NBSP = utf8.char(0xA0)" "$ROOT/src/client/Controllers/GainController.luau" 2>/dev/null; then
	exec bash "$N/a224-banc/run.sh" "$@"
fi
exec bash "$N/a232-banc/autres-bancs/a224/run224.sh" "$@"
