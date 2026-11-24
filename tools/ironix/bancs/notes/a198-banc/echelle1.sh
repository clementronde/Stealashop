#!/usr/bin/env bash
# a198 (vague 61) : lance un banc existant sur une copie de l'arbre remise comme avant a198 :
# Balance.REAL_SPEED_SCALE = 1 (vitesse réelle d'avant) et sans le WindowHP = 15 de la zone 1 (PV calculés, 27).
# Pour les bancs qui écrivent en dur des vitesses à l'échelle 1 (13,4, 16, 78, touché à 2,5 s…) ou les PV de la
# zone 1 ; la nouvelle échelle et les 15 PV sont vérifiés par le banc a198.
# Arbre sans REAL_SPEED_SCALE (avant a198) : le banc tourne sur l'arbre tel quel.
#   bash echelle1.sh <script du banc> <src|repo> <racine du dépôt>
set -u
SCRIPT="$1"
KIND="$2"
REPO="${3%/src}"
BALANCE="$REPO/src/shared/Config/Balance.luau"
if ! grep -q "^local REAL_SPEED_SCALE = " "$BALANCE" 2>/dev/null; then
	if [ "$KIND" = "src" ]; then exec bash "$SCRIPT" "$REPO/src"; else exec bash "$SCRIPT" "$REPO"; fi
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
for f in "$REPO"/*.md; do
	if [ -f "$f" ]; then cp "$f" "$TMP/"; fi
done
sed -i -E 's/^local REAL_SPEED_SCALE = [0-9.]+/local REAL_SPEED_SCALE = 1/' "$TMP/src/shared/Config/Balance.luau"
sed -i -E '/^[[:space:]]*WindowHP = 15,/d' "$TMP/src/shared/Config/Zones.luau"
if [ "$KIND" = "src" ]; then bash "$SCRIPT" "$TMP/src"; else bash "$SCRIPT" "$TMP"; fi
