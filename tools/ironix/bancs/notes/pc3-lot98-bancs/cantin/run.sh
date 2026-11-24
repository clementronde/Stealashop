#!/usr/bin/env bash
# lot98 (petit chef 3) : a262-banc/avant-cantin.pl retire toute ligne « \t\tCosts = {…}, » d'un fichier de Config (prévu
# pour Config/Upgrades). Depuis a280 (L-294), Config/ShopGrowth.Floor2 a aussi une telle ligne : retirée, Shared/ShopFloor
# plante au chargement (« attempt to get length of a nil value »). Ici : copie de l'arbre (src, tools, *.md ; pas docs) où
# cette ligne de ShopGrowth reçoit un commentaire en fin de ligne (avant-cantin.pl ne la voit plus), puis le banc d'avant
# sur la copie. Sans ligne à protéger : le banc tel quel.
#   bash run.sh <script du banc> <racine du dépôt> [arguments…]
set -u
SCRIPT="$1"
REPO="${2%/src}"
TAIL="${2#"$REPO"}"
shift 2
SG="$REPO/src/shared/Config/ShopGrowth.luau"
if ! grep -qP '^\t\tCosts = \{.*\},\r?$' "$SG" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO$TAIL" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
for f in "$REPO"/*.md; do
	if [ -f "$f" ]; then cp "$f" "$TMP/"; fi
done
perl -pi -e 's/^(\t\tCosts = \{.*\},)(\r?)$/$1 -- lot98 : protégé de avant-cantin.pl$2/' "$TMP/src/shared/Config/ShopGrowth.luau"
bash "$SCRIPT" "$TMP$TAIL" "$@"
