#!/usr/bin/env bash
# a302 (21/11, Cantin : bulles deux fois moins souvent, SpawnMin = 4 et SpawnMax = 6) : copie du lanceur a232 du banc a215 ;
# scénario order sur a302-banc/autres-bancs/a215/run215.sh (O2 attend SpawnMax + 0,1 s, lu dans Bubbles). Arbre encore à
# SpawnMin = 2 : le lanceur a232 tel quel.
# a232 (vague 70) : banc a215 sur le faux Roblox d a232, via a224-banc/corrige.sh (textes « Speed/s » d avant la vague 67) ;
# arbre sans a232 (pas de NBSP dans GainController) : le lanceur d avant (a224-banc/autres-bancs/a215).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if grep -qE "^[[:space:]]*SpawnMin = 2," "$ROOT/src/shared/Config/Bubbles.luau" 2>/dev/null; then
	exec bash "$N/a232-banc/autres-bancs/a215/run.sh" "$@"
fi
if ! grep -q "NBSP = utf8.char(0xA0)" "$ROOT/src/client/Controllers/GainController.luau" 2>/dev/null; then
	exec bash "$N/a224-banc/autres-bancs/a215/run.sh" "$@"
fi
exec bash "$N/a224-banc/corrige.sh" a215 "$N/a302-banc/autres-bancs/a215/run215.sh" "$@"
