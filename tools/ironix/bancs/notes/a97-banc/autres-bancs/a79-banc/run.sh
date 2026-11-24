#!/usr/bin/env bash
# Copie d'a97 (2026-11-12, vague 29, L-105 point 2) : le camion livré debout est couché à sa place (toutes ses pièces
# sauf Root) ; T5 compare la place du conducteur repris à la caisse (Pieces/Piece_01), plus à Root. Sur un arbre
# sans ArriveUpright (a97 pas encore fusionné), relance le banc d'origine (a79-banc) : bon avant et après la fusion.
if ! grep -q ArriveUpright "${1:-/f/StealAShop}/src/server/Services/TruckEventService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a79-banc/run.sh" "$@"; fi
# Banc hors Studio d'a79 (vague 26, 2026-11-11, L-097 point 3) : colis et camions au modèle de leur rareté.
#   shelf : sur le rayon (StoreHeistService) : BOX_<Rareté>, sinon BOX_<Tier>, sinon V0 ; pas reteint.
#           Mise en place du banc a17-heist (copie d'a66), lue sur place jusqu'à « démarrage ».
#   truck : camion ENV_Event_Truck_<rareté la plus haute du chargement>, repli sur ENV_Event_Truck (absent,
#           incomplet), conducteurs repris du camion de base ; colis lâchés au modèle de leur rareté (repli
#           sur BOX_<Tier>) ; porté (CarryService) au modèle de sa rareté, halo sans doublon des effets du
#           modèle, pas reteint. Faux Roblox et mise en place du banc a27 (copie d'a51), lus sur place.
#   floor : au sol de la boutique (UnboxService, FloorBox) et icônes ICON_BOX_<Rareté> de l'inventaire et
#           de la barre du bas, repli sur ICON_BOX_<Tier>. Faux Roblox et mise en place du banc a74.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-shelf truck floor}"
if ! grep -q "TRUCK_RARITY_FORMAT" "$SRC/server/Services/TruckEventService.luau" 2>/dev/null; then
	echo "banc a79 (colis et camions par rareté) : SAUTÉ, pas de camion par rareté dans $SRC (a79 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
HEIST="$H/../../../a66-banc/autres-bancs/a17-heist"
A27="$H/../../../a51-banc/autres-bancs/a27-banc"
A74="$H/../../../a74-banc"
A61="$H/../../../a62-banc/autres-bancs/a61-banc"
B51="$A61/autres-bancs/a51-banc"
B53="$A61/autres-bancs/a53-banc"

sources() {
	(cd "$SRC" && find "$@" -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	case "$name" in
	shelf)
		{
			cat "$HEIST/stubs.luau" "$HEIST/ext.luau" "$HEIST/../stub-anticheat.luau"
			sources shared server/Services/StoreHeistService.luau client/Controllers/HeistController.luau
			awk '/^-+ démarrage$/ { exit } { print }' "$HEIST/tests.luau"
			cat "$H/tests.shelf.luau"
		} > "$OUT"
		;;
	truck)
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$A27/stubs.luau" "$H/../../../a36-banc/autres-bancs/stub-anticheat.luau"
			sources shared server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/UnboxService.luau server/Services/ContractChecker.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau
			cat "$A27/setup.luau" "$H/tests.truck.luau"
		} > "$OUT"
		;;
	floor)
		# Avec les cases stables d'a76 (src/shared/HotbarLayout.luau) : sa copie du banc a74, HotbarService monté.
		X74="$A74/ext74.luau"
		S74="$A74/setup74.luau"
		HOTBAR_SERVICE=""
		if [ -f "$SRC/shared/HotbarLayout.luau" ]; then
			A76="$H/../../../a76-banc"
			X74="$A76/autres-bancs/a74-banc/ext74.luau $A76/ext76.luau"
			S74="$A76/autres-bancs/a74-banc/setup74.luau $A76/setup76.luau"
			HOTBAR_SERVICE="server/Services/HotbarService.luau"
		fi
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$A61/ext61.luau" $X74
			sources shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau $HOTBAR_SERVICE client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/HotbarController.luau client/Controllers/Unbox
			cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A61/setup61.luau" $S74 "$H/tests.floor.luau"
		} > "$OUT"
		;;
	esac
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.*[^0-9]([0-9]+) vérification.*/\1/; s/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a79 (colis et camions par rareté) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
