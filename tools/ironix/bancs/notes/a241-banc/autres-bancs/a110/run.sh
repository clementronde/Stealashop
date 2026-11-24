#!/usr/bin/env bash
# a241 (vague 72) : lanceur du banc a110 (a202-banc/autres-bancs/a110/run.sh) sur une copie de l'arbre à
# Config/Chase.ChaseOnEmptyExit = false : le banc a110 vérifie la règle d'avant (sorti sans rien, aucun vigile) ;
# la nouvelle (true) est vérifiée par le banc a241. Arbre sans ChaseOnEmptyExit : le lanceur d'avant tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "ChaseOnEmptyExit = true" "$REPO/src/shared/Config/Chase.luau" 2>/dev/null; then
	exec bash "$S/a202-banc/autres-bancs/a110/run.sh" "$REPO"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
sed -i -E 's/ChaseOnEmptyExit = true/ChaseOnEmptyExit = false/' "$TMP/src/shared/Config/Chase.luau"
bash "$S/a202-banc/autres-bancs/a110/run.sh" "$TMP"
