#!/usr/bin/env bash
# a180 (2026-11-15, vague 55) : lance un banc existant sur une copie de l'arbre où Training.Treadmill.SideEntryOnly = false.
# Pour les bancs dont les scénarios posent le joueur directement sur la bande du tapis (entrée, séance, gains,
# sortie, anti-triche…) : l'ancienne règle (on monte dès l'entrée dans la zone) reste dans le code, derrière
# l'interrupteur, et ces bancs la vérifient toujours. La nouvelle règle (entrée par un grand côté) est vérifiée
# par le banc a180.
# Sur un arbre sans SideEntryOnly (avant a180) : le banc tourne sur l'arbre tel quel.
#   bash regle-coupee.sh <script du banc> <src|repo> <racine du dépôt>
set -u
SCRIPT="$1"
KIND="$2"
REPO="${3%/src}"
TRAINING="$REPO/src/shared/Config/Training.luau"
if ! grep -q "SideEntryOnly = true" "$TRAINING" 2>/dev/null; then
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
sed -i 's/SideEntryOnly = true/SideEntryOnly = false/' "$TMP/src/shared/Config/Training.luau"
if [ "$KIND" = "src" ]; then bash "$SCRIPT" "$TMP/src"; else bash "$SCRIPT" "$TMP"; fi
