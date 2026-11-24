#!/usr/bin/env bash
# Copie a159 (2026-11-14, vague 50, L-163) de la copie a134 du banc a93 : scénario walls de la copie a159 du banc
# a84 (a159-banc/autres-bancs/a84/tests.walls.luau : 40 coups à tous les niveaux, Walls sans effet, Reinforced Door
# +8). Arbre sans PvP.DoorHits : lance la copie a134.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "DoorHits = " "$ROOT/src/shared/Config/PvP.luau" 2>/dev/null; then
	exec bash "$H/../../../a134-banc/autres-bancs/a93/run.sh" "$@"
fi
out=$(bash "$H/../a84/run.sh" "$ROOT" walls 2>&1)
code=$?
printf '%s\n' "$out" | grep -v "^banc a84 "
line=$(printf '%s\n' "$out" | grep -E "^banc a84 " | tail -1)
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a93 (tuile Walls, portes en coups) : ${c:-0} vérification(s), ${f:-1} échec(s)"
exit $code
