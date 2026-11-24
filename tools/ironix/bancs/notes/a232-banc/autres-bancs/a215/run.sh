#!/usr/bin/env bash
# a232 (vague 70) : banc a215 sur le faux Roblox d a232, via a224-banc/corrige.sh (textes « Speed/s » d avant la vague 67) ;
# arbre sans a232 (pas de NBSP dans GainController) : le lanceur d avant (a224-banc/autres-bancs/a215).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "NBSP = utf8.char(0xA0)" "$ROOT/src/client/Controllers/GainController.luau" 2>/dev/null; then
	exec bash "$N/a224-banc/autres-bancs/a215/run.sh" "$@"
fi
exec bash "$N/a224-banc/corrige.sh" a215 "$N/a232-banc/autres-bancs/a215/run215.sh" "$@"
