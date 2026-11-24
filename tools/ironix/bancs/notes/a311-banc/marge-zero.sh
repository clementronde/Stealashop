#!/usr/bin/env bash
# a311 (22/11) : copie d'a310-banc/marge-zero.sh qui accepte toute valeur de la marge (1,5 sur main, 2,25 avec a311).
# Lance un banc existant sur une copie de l'arbre où Training.Treadmill.SideEntryMargin = 0 (emprise d'entrée = la
# bande elle-même, comme avant a310). Pour les bancs d'avant a180 (règle du côté coupée par a180-banc/regle-coupee.sh)
# dont la zone de ±3 est entièrement couverte par la marge en travers. La marge elle-même est vérifiée par le banc
# a311. Arbre sans SideEntryMargin (avant a310) : le banc tourne sur l'arbre tel quel.
#   bash marge-zero.sh <script du banc> <racine du dépôt>
set -u
SCRIPT="$1"
REPO="${2%/src}"
TRAINING="$REPO/src/shared/Config/Training.luau"
if ! grep -qE "SideEntryMargin = [0-9.]+" "$TRAINING" 2>/dev/null; then
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
sed -i -E 's/SideEntryMargin = [0-9.]+/SideEntryMargin = 0/' "$TMP/src/shared/Config/Training.luau"
bash "$SCRIPT" "$TMP"
