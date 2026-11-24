#!/usr/bin/env bash
# lot98-commun (petit chef 2) : lance un banc sur une copie de l'arbre où Features.Bodyguards et CameraRadar = false (même
# principe que a407-banc/sans-outils.sh). a408 code Guards (Coded 5) et Cameras niveau 3 (L-163, L-175) : les bancs a84 et
# a85 vérifient l'arbre avec Guards « Soon » (Coded 0) et Cameras arrêté au niveau 2 ; ces deux tuiles codées sont
# vérifiées par le banc a408.
#   bash sans-defense.sh <racine du dépôt> <commande du banc…>   (la racine de la copie est ajoutée en dernier argument)
set -u
REPO="${1%/src}"
shift
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
for f in "$REPO"/*.md; do
	if [ -f "$f" ]; then cp "$f" "$TMP/"; fi
done
sed -i -E "s/^	(Bodyguards|CameraRadar) = true,/	\1 = false,/" "$TMP/src/shared/Config/Features.luau"
"$@" "$TMP"
