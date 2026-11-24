#!/usr/bin/env bash
# a311 (22/11) : lance un banc existant sur une copie de l'arbre où Training.Treadmill.SideEntryMargin = 1,5 (valeur
# d'a310). Pour les bancs dont les tapis n'ont pas de UseZone : leur zone de secours (boîte du modèle + 1 stud, X ±3
# dans le harnais a134 d'a65, cadre de 4 studs pour une bande de 3) est plus étroite que l'emprise élargie à 2,25
# (X ±3,75) ; le contrôle d'avant l'entrée tombe alors déjà dans l'emprise et l'entrée par le côté ne se voit plus
# (TrainingZone.track ne suit la bande que dans la zone choisie). Les vrais tapis ont tous une UseZone (L-207) : la
# marge de 2,25 et ce cas sont vérifiés par le banc a311. Arbre sans SideEntryMargin : le banc tel quel.
#   bash marge-a310.sh <script du banc> <racine du dépôt> [arguments…]
set -u
SCRIPT="$1"
REPO="${2:-/f/StealAShop}"
REPO="${REPO%/src}"
shift 2 2>/dev/null || shift $#
TRAINING="$REPO/src/shared/Config/Training.luau"
if ! grep -qE "SideEntryMargin = [0-9.]+" "$TRAINING" 2>/dev/null; then
	exec bash "$SCRIPT" "$REPO" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for d in src tools docs; do
	if [ -d "$REPO/$d" ]; then cp -r "$REPO/$d" "$TMP/$d"; fi
done
for f in "$REPO"/*.md; do
	if [ -f "$f" ]; then cp "$f" "$TMP/"; fi
done
sed -i -E 's/SideEntryMargin = [0-9.]+/SideEntryMargin = 1.5/' "$TMP/src/shared/Config/Training.luau"
bash "$SCRIPT" "$TMP" "$@"
