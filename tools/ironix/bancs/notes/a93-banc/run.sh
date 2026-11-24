#!/usr/bin/env bash
# Banc hors Studio d'a93 (2026-11-12, vague 29, L-105 point 3, L-106 points 2 et 3) : tuile Walls et PV des
# portes de boutique. Lance le scénario « walls » de la copie a93 du banc a84 (autres-bancs/a84-banc) :
# base par StageLevel (50 × dégâts conseillés de la zone du même rang), Walls × Glass sur la même barre,
# attribut WallsLevel et mur visible (ShopWallsService).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a93 ; après fusion : /f/StealAShop)
# Avant la fusion d'a93 (pas de ShopWallsService) : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a93}"
if [ ! -f "$ROOT/src/server/Services/ShopWallsService.luau" ]; then
	echo "banc a93 SAUTÉ : cet arbre n'a pas encore ShopWallsService"
	echo "banc a93 (tuile Walls, PV des portes) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
out=$(bash "$H/autres-bancs/a84-banc/run.sh" "$ROOT" walls 2>&1)
code=$?
printf '%s\n' "$out" | grep -v "^banc a84 "
line=$(printf '%s\n' "$out" | grep -E "^banc a84 " | tail -1)
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a93 (tuile Walls, PV des portes) : ${c:-0} vérification(s), ${f:-1} échec(s)"
exit $code
