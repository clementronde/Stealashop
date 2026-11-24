#!/usr/bin/env bash
# a153 (2026-11-14, vague 45) : lance un banc existant sur une copie de l'arbre où Features.GuardChaseV2 = false.
# Pour les bancs dont le sujet n'est pas la vitesse des poursuivants (batte, anti-triche, potions, braquage,
# nuit, camion, police…) mais dont les scénarios supposent l'ancienne vitesse (Zones[zone].GuardSpeed,
# Night.ChaseSpeed, × la marche, vitesse fixe du policier) : l'ancienne règle reste dans le code, derrière
# l'interrupteur, et ces bancs la vérifient toujours. La nouvelle règle est vérifiée par le banc a153.
# Sur un arbre sans GuardChaseV2 (avant a153) : le banc tourne sur l'arbre tel quel.
#   bash regle-coupee.sh <script du banc> <src|repo> <racine du dépôt>
set -u
SCRIPT="$1"
KIND="$2"
REPO="$3"
FEATURES="$REPO/src/shared/Config/Features.luau"
if ! grep -q "GuardChaseV2 = true" "$FEATURES" 2>/dev/null; then
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
sed -i 's/GuardChaseV2 = true/GuardChaseV2 = false/' "$TMP/src/shared/Config/Features.luau"
if [ "$KIND" = "src" ]; then bash "$SCRIPT" "$TMP/src"; else bash "$SCRIPT" "$TMP"; fi
