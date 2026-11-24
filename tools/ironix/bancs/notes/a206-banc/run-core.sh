#!/usr/bin/env bash
# Coeur du banc a206 (vague 63, L-202 point 4) sur le harnais d a142 (lu sur place : faux Roblox d a51 et extensions,
# setup142.luau) : scénario hand (objet retiré à la main : en main, sinon dans la réserve). Lancé par run.sh d ici,
# à travers a203-banc/corrige.sh et a158-banc/corrige.sh comme le banc a142. Sortie dans un dossier passager.
# --- en-tête d origine (a142) :
# Banc hors Studio d'a142 (2026-11-14, demande de Cantin) : l'objet de l'inventaire choisi dans la barre du bas
# UI_Hotbar va dans la main du joueur (HeldItemService, remote HoldItem, InventoryController.HoldItem,
# HotbarController), à la taille qu'il a sur un présentoir.
# Rien de copié : le faux Roblox et la mise en place du banc a118 (stubs d'a51, ext53, ext61, ext74, ext76,
# ext118 ; setup, setup61, setup74, setup76, ext105), lus sur place ; d'ici : setup142.luau (vrai
# HeldItemService, modèle ITM_Z3_Smartphone à 3 pièces, aides) et les scénarios tests.<nom>.luau :
#   hold    mise en main, rangement (même case, autre case, outil, batte), Equipped, refus du serveur,
#           rangement à l'exposition, au portage, à la mort, au départ, aucune duplication, antivol (mode pose
#           gardé), outil de casse mis en main près d'une vitrine
#   size    taille égale à celle du présentoir pour chaque taille de mutation (aucune, Tiny, Big, Huge,
#           Colossal), modèle ITM_ et bloc V0 ; prise en main (Grip) selon la taille
# Sur un arbre sans HeldItemService (avant a142) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-hand}"
A118="$N/a118-banc"
A76="$N/a76-banc"
A74="$A76/autres-bancs/a74-banc"
A61="$N/a62-banc/autres-bancs/a61-banc"
B51="$A61/autres-bancs/a51-banc"
B53="$A61/autres-bancs/a53-banc"
A105="$N/a105-banc"
if [ ! -f "$SRC/shared/Config/Displayed.luau" ]; then
	echo "banc a206 (présentoirs, réserve) : SAUTÉ, a206 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/HotbarService.luau server/Services/PvPService.luau server/Services/HeldItemService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/HotbarController.luau client/Controllers/Unbox client/Controllers/DisplayedController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$A61/ext61.luau" "$A74/ext74.luau" "$A76/ext76.luau" "$A118/ext118.luau"
		sources
		cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A61/setup61.luau" "$A74/setup74.luau" "$A76/setup76.luau" "$A105/ext105.luau" "$N/a142-banc/setup142.luau" "$H/setup206.luau" "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a206 (présentoirs : en main, réserve) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
