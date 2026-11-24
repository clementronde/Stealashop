#!/usr/bin/env bash
# Banc hors Studio d'a262 (vague 76, 2026-11-19, Cantin et Clément) : raretés par zone (objets et colis), tables à 100,
# revenus croissants dans l'ordre de l'index, aucune rareté hors zone (catalogue, contenu des caisses, améliorations
# d'UnboxPlan), vraie cote « 1 IN N » cohérente (Shared/ItemOdds, Formulas.UnboxOdds). Charge les vrais modules de
# src/shared avec un petit chargeur (loader.luau : script.Parent, WaitForChild, Color3), sans faux Roblox.
#   bash run.sh [racine du dépôt]   RAPPORT=1 : imprime aussi les tables du rapport (revenus, chances, exemples de N)
# Arbre sans la vague 76 (pas de ZoneRarities dans Config/ShelfBoxes) : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LABEL="banc a262 (raretés par zone, revenus, vraie cote)"
if ! grep -q "ZoneRarities" "$SRC/shared/Config/ShelfBoxes.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, pas de ShelfBoxes.ZoneRarities dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	echo "SOURCES = {}"
	echo "RAPPORT = ${RAPPORT:-0} == 1"
	(cd "$SRC/shared" && find . -name '*.luau' | sed 's|^\./||' | sort) | awk -v root="$SRC/shared" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/loader.luau"
	cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
