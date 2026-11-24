#!/usr/bin/env bash
# a221 (2026-11-16, vague 66, L-210 point 4 : le témoin fonce et photographie dès son arrivée) : lance un banc existant sur
# une copie de l'arbre où Witness.Photo.Rush = false (l'approche d'a196 et Look à l'arrivée). Pour les bancs dont les
# scénarios supposent ce déroulé ; le nouveau est vérifié par le banc a221. Sans Photo.Rush (avant a221) : l'arbre tel quel.
#   bash regle-coupee.sh <script du banc> <src|repo> <racine du dépôt>
set -u
SCRIPT="$1"
KIND="$2"
REPO="${3%/src}"
CONFIG="$REPO/src/shared/Config/Witness.luau"
if ! grep -q "Rush = true" "$CONFIG" 2>/dev/null; then
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
perl -pi -e 's/^(\s*Rush = )true/${1}false/' "$TMP/src/shared/Config/Witness.luau"
if [ "$KIND" = "src" ]; then bash "$SCRIPT" "$TMP/src"; else bash "$SCRIPT" "$TMP"; fi
