#!/usr/bin/env bash
# a288 (21/11) : lance le banc <run.sh> sur une copie de l'arbre où Config/Witness.Crowd.Trigger vaut "Exit" (l'ancien
# moment de la foule, L-210 point 4), pour prouver que ce moment n'a pas bougé. Arbre sans Crowd.Trigger : le banc tel quel.
#   bash exit.sh <run.sh du banc> [racine du dépôt]
set -u
BANC="$1"
ROOT="${2:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'Trigger = "Enter"' "$ROOT/src/shared/Config/Witness.luau" 2>/dev/null; then
	exec bash "$BANC" "$ROOT"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -r "$ROOT/src" "$TMP/src"
perl -pi -e 's/Trigger = "Enter"/Trigger = "Exit"/' "$TMP/src/shared/Config/Witness.luau"
bash "$BANC" "$TMP"
