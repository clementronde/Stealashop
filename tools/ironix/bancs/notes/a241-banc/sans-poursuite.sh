#!/usr/bin/env bash
# a241 (vague 72) : lance un banc existant sur une copie de l'arbre à Config/Chase.ChaseOnEmptyExit = false (règle d'avant :
# sorti sans objet avant la fin du chrono, aucun vigile). Pour les bancs dont les scénarios sortent un joueur sans objet
# d'un magasin pendant son chrono (sortie sur le trottoir, ou téléportation d'un magasin à l'autre) pour vérifier autre
# chose ; la nouvelle règle est vérifiée par le banc a241. Arbre sans ChaseOnEmptyExit = true : le banc tel quel.
#   bash sans-poursuite.sh <script du banc> <racine du dépôt> [arguments…]
set -u
SCRIPT="$1"
REPO="${2%/src}"
shift 2
if ! grep -q "ChaseOnEmptyExit = true" "$REPO/src/shared/Config/Chase.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
sed -i -E 's/ChaseOnEmptyExit = true/ChaseOnEmptyExit = false/' "$TMP/src/shared/Config/Chase.luau"
bash "$SCRIPT" "$TMP" "$@"
