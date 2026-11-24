#!/usr/bin/env bash
# Banc hors Studio d'a295 (21/11, vague 84, V0 choisie par le grand chef le 21/11) : le camion ne lâche plus de colis
# vides. La table du camion (Rarities.BoxOdds par ShelfBoxes.OddsFor) perd seulement les raretés qui finissaient vides
# (aucun objet à leur niveau ni en dessous dans la zone), ramenée à 100 (TruckEventService.truckOdds), repli vers le bas
# gardé : zones 1 à 4 identiques à avant (calcul exact + échantillon), zones 5 et 6 = avant parmi les colis non vides.
# Charge les vrais modules de src/shared avec le chargeur du banc a262 (loader.luau), plus la partie « Tirage » du
# vrai TruckEventService (de « -- Tirage (comme un rayon » à « -- Largeur au sol d'un colis »), mise en module.
#   bash run.sh [racine du dépôt]   RAPPORT=1 : imprime les tables (avant / après, colis vides par zone)
#   AVANT=1 : tourne aussi sur un arbre sans a295 (montre les colis vides du vieux code ; échecs attendus)
# Arbre sans a295 (pas de truckOdds dans TruckEventService) : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
L="$H/../a262-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
SERVICE="$SRC/server/Services/TruckEventService.luau"
LABEL="banc a295 (camion sans colis vides)"
if ! grep -q "local function truckOdds" "$SERVICE" 2>/dev/null && [ "${AVANT:-}" != "1" ]; then
	echo "$LABEL : SAUTÉ, pas de truckOdds dans $SERVICE : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
DRAW="$(tr -d '\r' < "$SERVICE" | awk '/^-- Tirage \(comme un rayon/ { on = 1 } /^-- Largeur au sol d.un colis/ { on = 0 } on')"
if [ -z "$DRAW" ]; then
	echo "$LABEL : ÉCHEC, partie « Tirage » introuvable dans $SERVICE : 0 vérification(s), 1 échec(s)"
	exit 1
fi
{
	echo "SOURCES = {}"
	echo "RAPPORT = ${RAPPORT:-0} == 1"
	(cd "$SRC/shared" && find . -name '*.luau' | sed 's|^\./||' | sort) | awk -v root="$SRC/shared" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	echo 'SOURCES["TruckDraw295.luau"] = [==========['
	cat "$H/entete.luau"
	printf '%s\n' "$DRAW"
	echo 'return { drawLoad = drawLoad, drawContent = drawContent, truckOdds = (truckOdds :: any) }'
	echo ']==========]'
	cat "$L/loader.luau"
	cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
