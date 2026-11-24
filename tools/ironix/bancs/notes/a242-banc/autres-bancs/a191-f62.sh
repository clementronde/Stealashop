#!/usr/bin/env bash
# a242 (vague 72) : copie de f62-banc/autres-bancs/a191/run.sh, sur la copie a242 du lanceur a191 (a242-banc/autres-bancs/a191 :
# ShowReserve remis à true pour les scénarios d avant, nouveau scénario a242). NewAuras pas à true : sans a218.
N="$(cd "$(dirname "$0")/../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q '^[[:space:]]*NewAuras = true,' "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$N/f57-banc/corrige.sh" a191 "$N/a242-banc/autres-bancs/a191/run.sh" "$@"
fi
exec bash "$N/a218-banc/corrige.sh" anciennes-auras bash "$N/f57-banc/corrige.sh" a191 "$N/a242-banc/autres-bancs/a191/run.sh" "$@"
