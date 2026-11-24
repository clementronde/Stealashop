#!/usr/bin/env bash
# a284 (vague GC3, 23/11) : lance un banc existant sur une copie de l'arbre remise à la cadence d'avant a284
# (Balance.Window.RegenSyncHz = 10, soit HPSyncHz : WindowHP de la régénération 10 fois par seconde). Pour les bancs qui
# comptent les WindowHP de la régénération ou lisent ses PV au dixième de seconde ; la cadence de 2 par seconde est
# vérifiée par le banc a284. Arbre sans RegenSyncHz : le banc sur l'arbre tel quel.
#   bash regen10.sh <lanceur du banc> <racine du dépôt, ou son dossier src> [autres arguments]
set -u
SCRIPT="$1"
REPO="${2%/src}"
TAIL="${2#"$REPO"}"
shift 2
if ! grep -q "RegenSyncHz = 2," "$REPO/src/shared/Config/Balance.luau" 2>/dev/null; then
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
sed -b -i 's/RegenSyncHz = 2,/RegenSyncHz = 10,/' "$TMP/src/shared/Config/Balance.luau"
bash "$SCRIPT" "$TMP$TAIL" "$@"
