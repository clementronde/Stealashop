#!/usr/bin/env bash
# a182 (2026-11-15, vague 56, L-172 : le témoin qui filme la casse) : lance un banc existant sur une copie de l'arbre
# où Witness.Photo.Enabled = false (l'ancien déroulé : il regarde sur place, reprend sa balade après l'appel). Pour
# les bancs dont les scénarios supposent cet ancien déroulé ; le nouveau est vérifié par le banc a182.
# Sur un arbre sans Witness.Photo (avant a182) : le banc tourne sur l'arbre tel quel.
#   bash regle-coupee.sh <script du banc> <src|repo> <racine du dépôt>
set -u
SCRIPT="$1"
KIND="$2"
REPO="${3%/src}"
CONFIG="$REPO/src/shared/Config/Witness.luau"
if ! grep -q "Photo = {" "$CONFIG" 2>/dev/null; then
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
perl -0pi -e 's/(Photo = \{.*?Enabled = )true/${1}false/s' "$TMP/src/shared/Config/Witness.luau"
if [ "$KIND" = "src" ]; then bash "$SCRIPT" "$TMP/src"; else bash "$SCRIPT" "$TMP"; fi
