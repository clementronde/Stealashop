#!/usr/bin/env bash
# a407 (vague GC6, 23/11) : lance un banc existant sur une copie de l arbre où Features.RebirthTools = false (pas d outil
# de renaissance dans Config/Tools). Pour les bancs qui comptent les 7 armes de la boutique ou les récompenses des
# renaissances 1 à 10 d avant a407 : l échelle ordinaire des armes ne change pas ; les outils de renaissance sont vérifiés
# par le banc a407. Arbre sans RebirthTools = true : le banc tel quel.
#   bash sans-outils.sh <script du banc> <src|repo> <racine du dépôt>
set -u
SCRIPT="$1"
KIND="$2"
REPO="${3%/src}"
FEATURES="$REPO/src/shared/Config/Features.luau"
if ! grep -q "^	RebirthTools = true," "$FEATURES" 2>/dev/null; then
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
sed -i "s/^	RebirthTools = true,/	RebirthTools = false,/" "$TMP/src/shared/Config/Features.luau"
if [ "$KIND" = "src" ]; then bash "$SCRIPT" "$TMP/src"; else bash "$SCRIPT" "$TMP"; fi
