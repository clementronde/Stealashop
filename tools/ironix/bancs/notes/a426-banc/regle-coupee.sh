#!/usr/bin/env bash
# a426 (24/11, L-319) : lance un banc existant sur une copie de l'arbre où Features.SafeZoneSpeed = false.
# Pour les bancs dont le sujet n'est pas la vitesse de la zone safe, mais dont les scénarios supposent la vitesse de la
# formule (ou la vitesse fixe de l'objet volé) dans une zone taggée SafeZone de leur faux arbre : l'ancienne règle reste
# dans le code, derrière l'interrupteur, et ces bancs la vérifient toujours. La nouvelle règle est vérifiée par le banc a426.
# Sur un arbre sans SafeZoneSpeed = true (avant a426) : le banc tourne sur l'arbre tel quel.
#   bash regle-coupee.sh <script du banc> <src|repo> <racine du dépôt> [arguments du banc…]
set -u
SCRIPT="$1"
KIND="$2"
REPO="${3%/src}"
shift 3
FEATURES="$REPO/src/shared/Config/Features.luau"
if ! grep -q "SafeZoneSpeed = true" "$FEATURES" 2>/dev/null; then
	if [ "$KIND" = "src" ]; then exec bash "$SCRIPT" "$REPO/src" "$@"; else exec bash "$SCRIPT" "$REPO" "$@"; fi
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
for f in "$REPO"/*.md; do
	if [ -f "$f" ]; then cp "$f" "$TMP/"; fi
done
sed -i 's/SafeZoneSpeed = true/SafeZoneSpeed = false/' "$TMP/src/shared/Config/Features.luau"
if [ "$KIND" = "src" ]; then bash "$SCRIPT" "$TMP/src" "$@"; else bash "$SCRIPT" "$TMP" "$@"; fi
