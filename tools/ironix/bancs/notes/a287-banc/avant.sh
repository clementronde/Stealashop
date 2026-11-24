#!/usr/bin/env bash
# a287 (2026-11-21, Cantin : plusieurs coups pour un Commun, cote qui monte d'un bout à l'autre) : lance un banc
# existant sur une copie de l'arbre aux règles d'avant : Config/Unbox.New.ActionsByRarity d'avant (Commun 1 à Divin 8)
# et New.OddsClimb.Enabled = false (cote dans la plage de la rareté montrée, cachée pendant les silhouettes). Les
# nouvelles règles sont vérifiées par le banc a287 ; ceci prouve que l'interrupteur rend la cote d'avant. Arbre sans
# OddsClimb : le banc tel quel.
#   bash avant.sh <script du banc> <racine du dépôt> [arguments…]
set -u
SCRIPT="$1"
REPO="${2:-/f/StealAShop}"
REPO="${REPO%/src}"
shift 2 || shift $#
CFG="src/shared/Config/Unbox.luau"
if ! grep -q "OddsClimb = {" "$REPO/$CFG" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
perl -0pi -e 's/ActionsByRarity = \{[^}]*\}/ActionsByRarity = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7, Divine = 8 }/; s/(OddsClimb = \{\s*Enabled = )true/${1}false/' "$TMP/$CFG"
if ! grep -q "Common = 1, Uncommon = 2" "$TMP/$CFG" || ! grep -Pzo "OddsClimb = \{\s*Enabled = false" "$TMP/$CFG" > /dev/null; then
	echo "ÉCHEC a287 : arbre d'avant pas préparé : 0 vérification(s), 1 échec(s)"
	exit 1
fi
bash "$SCRIPT" "$TMP" "$@"
