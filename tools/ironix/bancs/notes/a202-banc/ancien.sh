#!/usr/bin/env bash
# a202 (vague 62, L-198) : lance un banc existant sur une copie de l'arbre remise à l'ouverture d'avant :
# Features.SingleBoxReveal = false (chance qui monte, objet posé sur le rayon et réservé, prise par GrabItem).
# Pour les bancs qui ouvrent un colis puis prennent l'objet sur le rayon ; le nouveau déroulé (un seul colis,
# cinématique, objet porté d'office) est vérifié par le banc a202.
# Arbre sans SingleBoxReveal = true (avant a202) : le banc tourne sur l'arbre tel quel.
#   bash ancien.sh <script du banc> <src|repo> <racine du dépôt>
set -u
SCRIPT="$1"
KIND="$2"
REPO="${3%/src}"
FEATURES="$REPO/src/shared/Config/Features.luau"
if ! grep -q "SingleBoxReveal = true" "$FEATURES" 2>/dev/null; then
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
sed -i -E 's/SingleBoxReveal = true/SingleBoxReveal = false/' "$TMP/src/shared/Config/Features.luau"
if [ "$KIND" = "src" ]; then bash "$SCRIPT" "$TMP/src"; else bash "$SCRIPT" "$TMP"; fi
