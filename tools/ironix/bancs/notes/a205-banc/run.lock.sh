#!/usr/bin/env bash
# Banc a205 (vague 63, L-202 point 3) : LockIcon de BB_AntiTheft caché à « UNLOCKED! ». Copie du lanceur d a178 (chaîne lue sur place), tests d ici.
#   take        invite « Take » (E) sur un objet exposé chez soi : TakeDisplayItem, inventaire et barre du bas,
#               refus (loin, autre joueur, tenu par un voleur), barre pleine → inventaire, inventaire plein
#   unlock      fin de l'antivol : invite « Take », l'objet va en main (mains libres) sinon dans l'inventaire,
#               jamais posé tout seul sur un présentoir
#   display     objet tenu : invite « Display » sur chaque présentoir libre de sa boutique, PlaceItem, refus loin
#   deposit     HeldItem.DepositToHand = true (défaut) : objet volé déposé en main / inventaire, jamais exposé
#   depositoff  HeldItem.DepositToHand = false (pre.depositoff.luau) : l'ancien déroulé (présentoir libre)
# Rien de copié : chaîne du banc a142 (faux Roblox d'a51, ext53, ext61, ext74, ext76, ext118 ; setup, setup61,
# setup74, setup76, ext105, setup142), lue sur place ; d'ici : setup152.luau (vrai DisplayController, aides).
# Sur un arbre sans TakeDisplayItem (avant a152) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-lock}"
A142="$H/../a142-banc"
A118="$H/../a118-banc"
A76="$H/../a76-banc"
A74="$A76/autres-bancs/a74-banc"
A61="$H/../a62-banc/autres-bancs/a61-banc"
B51="$A61/autres-bancs/a51-banc"
B53="$A61/autres-bancs/a53-banc"
A105="$H/../a105-banc"
if ! grep -q "LockShowDistance" "$SRC/shared/Config/Unbox.luau" 2>/dev/null; then
	echo "banc a178 (verrou de l antivol) : SAUTÉ, a178 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/HotbarService.luau server/Services/PvPService.luau server/Services/HeldItemService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/HotbarController.luau client/Controllers/DisplayController.luau client/Controllers/Unbox"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$A61/ext61.luau" "$A74/ext74.luau" "$A76/ext76.luau" "$A118/ext118.luau"
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A61/setup61.luau" "$A74/setup74.luau" "$A76/setup76.luau" "$A105/ext105.luau" "$A142/setup142.luau" "$H/../a152-banc/setup152.luau" "$H/../a152-banc/steal152.luau" "$H/tests.$name.luau"
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
echo "banc a205 cadenas : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
