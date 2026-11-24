#!/usr/bin/env bash
# a310 (22/11) : lance un banc existant sur une copie de l'arbre où Training.Treadmill.SideEntryMargin = 0 (emprise
# d'entrée = la bande elle-même, comme avant a310). Pour les bancs d'avant a180 (règle du côté coupée par
# a180-banc/regle-coupee.sh) dont les scénarios sortent de la bande de moins de 1,5 stud, sans sortir de la zone
# (bande ±1,5 et zone ±3 dans leur harnais : la marge de 1,5 couvre toute la zone en travers). La remontée a115
# (quitter le cœur puis y revenir) et le reste sont vérifiés tels quels ; la marge de 1,5 est vérifiée par le banc
# a310. Arbre sans SideEntryMargin (avant a310) : le banc tourne sur l'arbre tel quel.
#   bash marge-zero.sh <script du banc> <racine du dépôt>
set -u
SCRIPT="$1"
REPO="${2%/src}"
TRAINING="$REPO/src/shared/Config/Training.luau"
if ! grep -q "SideEntryMargin = 1.5" "$TRAINING" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
for f in "$REPO"/*.md; do
	if [ -f "$f" ]; then cp "$f" "$TMP/"; fi
done
sed -i 's/SideEntryMargin = 1.5/SideEntryMargin = 0/' "$TMP/src/shared/Config/Training.luau"
bash "$SCRIPT" "$TMP"
