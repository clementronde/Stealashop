#!/usr/bin/env bash
# Banc hors Studio d'a207 (vague 63, L-201 : UI_Index_v3 refait ; carte ITEM SECURED avec RarityFx). Scénarios :
#   refonte  faux UI_Index_v3 de lib67 (a117-banc/autres-bancs/a40-v3) refait par lib207.luau : ville et thème,
#            RewardIcon de la barre, ItemReward, ClaimButton en 3 états (gris, ReadyGradient + ClaimAlert, CLAIMED),
#            compteur « N / 83 discovered », LimitedButton caché, ZoneItem plus peint
#   ancien   le faux UI_Index_v3 d'avant (sans les nouveaux éléments) : sans erreur
#   contrat  Contract/UI (nouveaux éléments facultatifs, retirés hors contrat) et le vrai ContractChecker
#   carte    UI_Escape.Card de CatchSceneController (mise en place du banc a192, scénario client) : RarityFx
# Arbre sans a207 (pas de V3_CLAIMED_TEXT dans IndexController) : SAUTÉ.
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
B="$N/a117-banc/autres-bancs/a40-v3"
A53="$N/a53-banc"
A68="$N/a71-banc/autres-bancs/a68-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a207 (index v3 refait, carte avec RarityFx)"
if ! grep -q "V3_CLAIMED_TEXT" "$SRC/client/Controllers/IndexController.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, a207 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-refonte ancien contrat carte}"
INDEX_FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau server/Services/ContractChecker.luau server/Services/CosmeticService.luau server/Services/InventoryService.luau client/Controllers/IndexController.luau client/Controllers/UI/Motion.luau"
CARD_FILES="shared client/Controllers/UI client/Controllers/ChaseFeelController.luau client/Controllers/ChaseController.luau client/Controllers/MusicController.luau client/Controllers/CatchSceneController.luau client/Controllers/NotifyController.luau client/Controllers/ZoneGateController.luau client/Controllers/StoreInfoController.luau client/Controllers/TruckController.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/ContractChecker.luau"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		if [ "$name" = "carte" ]; then
			cat "$A68/stubs.luau" "$H/ext207.luau"
			sources "$CARD_FILES"
			cat "$N/a192-banc/pre.client.luau" "$N/a71-banc/autres-bancs/a42-banc/setup.luau" "$A68/common.luau" "$N/a192-banc/head.client.luau"
		else
			cat "$B/stubs.luau" "$B/ext29.luau" "$B/ext38.luau" "$B/stub-anticheat.luau" "$A53/ext51.luau" "$B/ext67.luau"
			sources "$INDEX_FILES"
			cat "$B/features.luau" "$B/pre.on.luau" "$B/setup.luau" "$A53/autres-bancs/compat51.luau" "$B/lib67.luau" "$H/lib207.luau"
		fi
		cat "$H/tests.$name.luau"
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
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
