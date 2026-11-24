#!/usr/bin/env bash
# a285 (21/11) : lance un banc existant sur une copie de l'arbre où la caisse exclusive est remise « pas codée »
# (Monetization.Crate.Ready = false, comme avant a285) : pour les bancs qui vérifient le « Soon » d'une caisse sans don
# (a208, cas a218). Le don codé (Ready = true) est vérifié par le banc a285. Arbre sans a285 : le banc tel quel.
#   bash caisse-pas-codee.sh <lanceur du banc> <racine du dépôt, ou son dossier src> [autres arguments]
set -u
SCRIPT="$1"
REPO="${2%/src}"
TAIL="${2#"$REPO"}"
shift 2
M="src/shared/Config/Monetization.luau"
if ! grep -q "Ready = true, -- a285" "$REPO/$M" 2>/dev/null; then
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
sed -i 's/Ready = true, -- a285/Ready = false, -- a285 (banc : remis pas codé)/' "$TMP/$M"
if ! grep -q "Ready = false, -- a285 (banc" "$TMP/$M"; then
	echo "caisse-pas-codee.sh : Crate.Ready introuvable : 0 vérification(s), 1 échec(s)"
	exit 1
fi
bash "$SCRIPT" "$TMP$TAIL" "$@"
