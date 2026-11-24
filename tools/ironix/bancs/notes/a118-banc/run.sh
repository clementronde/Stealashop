#!/usr/bin/env bash
# Banc hors Studio d'a118 (vague 34, 2026-11-13, L-127 de Clément, points 3 et 4) : antivol visible (chaînes et
# cadenas de FX_AntiTheft sur l'objet au sol, posés puis retirés à UNLOCKED ; voile AntiTheft des cartes de
# l'inventaire et des cases de la barre du bas, LockLabel) et pastilles CardAlert / SlotAlert (allumées, Pulse qui
# bat, éteintes quand l'action est faite).
# Rien de copié : le faux Roblox et la mise en place de la copie a76 du banc a74 (stubs d'a51, ext53, ext61, ext74,
# ext76, setup, setup61, setup74, setup76 : écrans UI_Inventory et UI_Hotbar), plus ext105 (antivol au sol, vrai
# PvPService), lus sur place ; d'ici : ext118 (CFrame.fromMatrix, Model:ScaleTo), setup118 (module AntiTheftChains,
# kit FX_AntiTheft, éléments de Clément ajoutés aux Templates), tests.<scénario>.luau.
# Sur un arbre sans Unbox/AntiTheftChains (avant a118) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop ; scénario : client)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-client}"
A76="$H/../a76-banc"
A74="$A76/autres-bancs/a74-banc"
A61="$H/../a62-banc/autres-bancs/a61-banc"
B51="$A61/autres-bancs/a51-banc"
B53="$A61/autres-bancs/a53-banc"
A105="$H/../a105-banc"
if [ ! -f "$SRC/client/Controllers/Unbox/AntiTheftChains.luau" ]; then
	echo "banc a118 (antivol visible, pastilles) : SAUTÉ, a118 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/HotbarService.luau server/Services/PvPService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/HotbarController.luau client/Controllers/Unbox"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$A61/ext61.luau" "$A74/ext74.luau" "$A76/ext76.luau" "$H/ext118.luau"
		sources
		cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A61/setup61.luau" "$A74/setup74.luau" "$A76/setup76.luau" "$A105/ext105.luau" "$H/setup118.luau" "$H/tests.$name.luau"
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
echo "banc a118 (antivol visible, pastilles) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
