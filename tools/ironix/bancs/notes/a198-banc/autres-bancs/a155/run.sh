#!/usr/bin/env bash
# a198 (vague 61) : lanceur du banc a155 (celui d'a190, a190-banc/autres-bancs/a155) sur la copie a198 du banc
# (../a155-banc : Formulas.MaxWalkSpeed dans le faux Config, lu par StatsService). Arbre sans REAL_SPEED_SCALE
# (avant a198) : le lanceur d'a190 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "^local REAL_SPEED_SCALE = " "$REPO/src/shared/Config/Balance.luau" 2>/dev/null; then
	exec bash "$H/a190-banc/autres-bancs/a155/run.sh" "$@"
fi
if [ ! -f "$REPO/src/shared/Config/Hud.luau" ]; then
	exec bash "$H/a198-banc/autres-bancs/a155-banc/run.sh" "$@"
fi
exec bash "$H/a190-banc/corrige.sh" a155 bash "$H/a198-banc/autres-bancs/a155-banc/run.sh" "$@"
