#!/usr/bin/env bash
# a407 (vague GC6, 23/11) : lanceur d avant du banc a159 (a183-banc/autres-bancs/a159/run.sh) avec a407-banc/patches/a159.sed
# (faux ToolService complété de GetDoorHits, que WindowService lit depuis a407) ; arbre sans GetDoorHits : le lanceur d avant.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "ToolService.GetDoorHits" "$REPO/src/server/Services/WindowService.luau" 2>/dev/null; then
	exec bash "$H/a183-banc/autres-bancs/a159/run.sh" "$@"
fi
exec bash "$H/a407-banc/corrige.sh" a159 bash "$H/a183-banc/autres-bancs/a159/run.sh" "$@"
