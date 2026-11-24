#!/usr/bin/env bash
# a251 (vague 73, L-236) : lance un banc existant sur une copie de l'arbre où la nouvelle ouverture du colis est coupée
# (Config/Unbox.New.Enabled = false : ni plan dans RevealStarted, ni nouveau plafond de la phase). Pour les bancs qui
# vérifient la cinématique d'avant ; la nouvelle est vérifiée par le banc a251. Arbre sans a251 : le banc tel quel.
#   bash avant.sh <script du banc> <racine du dépôt> [arguments…]
set -u
SCRIPT="$1"
REPO="${2%/src}"
shift 2
if [ ! -f "$REPO/src/shared/UnboxPlan.luau" ]; then
	exec bash "$SCRIPT" "$REPO" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
sed -i -E 's/^(\t\tEnabled = )true(, -- interrupteur ; false = la cinématique d.avant)/\1false\2/' "$TMP/src/shared/Config/Unbox.luau"
grep -q "Enabled = false, -- interrupteur ; false = la cinématique d" "$TMP/src/shared/Config/Unbox.luau" || { echo "a251 avant.sh : interrupteur New.Enabled introuvable"; exit 1; }
bash "$SCRIPT" "$TMP" "$@"
