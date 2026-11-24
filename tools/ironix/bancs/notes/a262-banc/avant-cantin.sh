#!/usr/bin/env bash
# a262 (vague 76, corrections de Cantin du 20/11 : vraies chances visées sur l'objet, prix remis à l'échelle) : lance un
# banc existant sur une copie de l'arbre remise comme avant ces corrections (avant-cantin.pl : prix, argent,
# ShelfStepUp, chances des colis, listes Costs). Pour les bancs qui écrivent en dur des prix, des PV de vitrine
# (lus après a226-banc/avant.sed, qui reconnaît les prix d'avant) ou les tirages d'avant ; les nouvelles valeurs sont
# vérifiées par le banc a262. Arbre sans ces corrections (pas de ShelfStepUp) : le banc sur l'arbre tel quel.
#   bash avant-cantin.sh <lanceur du banc> <racine du dépôt, ou son dossier src> [autres arguments]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$1"
REPO="${2%/src}"
TAIL="${2#"$REPO"}"
shift 2
if ! grep -q "ShelfStepUp" "$REPO/src/shared/Config/ShelfOpen.luau" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO$TAIL" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
for f in "$REPO"/*.md; do
	if [ -f "$f" ]; then cp "$f" "$TMP/"; fi
done
for f in "$TMP"/src/shared/Config/*.luau; do
	if grep -q "Cantin, 20/11\|Costs = {" "$f"; then
		perl "$H/avant-cantin.pl" "$f" || exit 1
	fi
done
bash "$SCRIPT" "$TMP$TAIL" "$@"
