#!/usr/bin/env bash
# a254 (vague 73, L-240 point 3) : lance un banc existant sur une copie de l'arbre à Config/Announce.Enabled = false
# (règle d'avant : les annonces partent par Notify, mêmes textes, ni annonce de jour ni de vol). Pour les bancs qui
# lisent l'annonce de nuit (a239) ou de la chance du serveur (a247) dans Notify ; la nouvelle règle est vérifiée par le
# banc a254. Arbre sans Config/Announce : le banc tel quel.
#   bash annonce-coupee.sh <script du banc> <racine du dépôt> [arguments…]
set -u
SCRIPT="$1"
REPO="${2%/src}"
shift 2
if ! grep -q "Enabled = true, -- interrupteur ; false = comme avant" "$REPO/src/shared/Config/Announce.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
sed -i -E 's/Enabled = true, -- interrupteur ; false = comme avant/Enabled = false, -- interrupteur ; false = comme avant/' "$TMP/src/shared/Config/Announce.luau"
bash "$SCRIPT" "$TMP" "$@"
