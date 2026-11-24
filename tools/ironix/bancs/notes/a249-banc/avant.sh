#!/usr/bin/env bash
# a249 (poursuite phase 2, L-235) : lance un banc existant sur une copie de l'arbre aux interrupteurs a249 coupés (règles
# d'avant : Chase.SpringReturn = false, la ruée ; StartDelay = 0.5, le délai de réaction ; WaitAfterReveal = false, reprise
# tout de suite après la cinématique ; OneCatchAtATime = false ; Zone1SpeedRequired = 0, zone 1 sans minimum). Pour les
# bancs qui vérifient ces règles d'avant ; les nouvelles sont vérifiées par le banc a249. Arbre sans a249 : le banc tel quel.
#   bash avant.sh <script du banc> <racine du dépôt> [arguments…]
set -u
SCRIPT="$1"
REPO="${2%/src}"
shift 2
if ! grep -q "SpringReturn = true" "$REPO/src/shared/Config/Chase.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
sed -i -E -e 's/Zone1SpeedRequired = 10,/Zone1SpeedRequired = 0,/' -e 's/SpringReturn = true,/SpringReturn = false,/' \
	-e 's/StartDelay = 1,/StartDelay = 0.5,/' -e 's/WaitAfterReveal = true,/WaitAfterReveal = false,/' \
	-e 's/OneCatchAtATime = true,/OneCatchAtATime = false,/' "$TMP/src/shared/Config/Chase.luau"
bash "$SCRIPT" "$TMP" "$@"
