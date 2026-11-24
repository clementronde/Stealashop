#!/usr/bin/env bash
# Copie a255 (vague 73, L-241, décision de Cantin du 18/11) : Config/Displayed.ShowReserve revient à true. Le scénario
# a242 tourne avec ShowReserve forcé à false (hide-reserve.luau : l interrupteur et son repli restent) ; tests.displayed
# d ici : réserve vide montrée (plus cachée) ; nouveau scénario a255 (InventoryButton de UI_Hotbar, pastille
# InventoryAlert, ReserveEmpty, Toggle sur l écran réel).
# Copie a242 (vague 72, L-219 point 4, L-231, 2026-11-17) : Config/Displayed.ShowReserve = false (la réserve sort de
# UI_Displayed). Les scénarios d avant (displayed, reserve, a219, a219off, …) tournent avec ShowReserve remis à true
# (show-reserve.luau, lu avant eux) ; nouveau scénario a242 (ShowReserve = false, flèche CloseArrowButton, lignes
# gardées quand rien ne change). Arbre sans ShowReserve : rien n est corrigé (show-reserve.luau ne trouve rien).
# Copie a219 (vague 66, L-210 point 2, 2026-11-16) : tests.reserve et tests.displayed d ici (réserve qui prend tout objet
# libre, échange quand tout est pris) ; nouveaux scénarios a219 et a219off (a219-common.luau lu avant eux).
# Copie a206 (vague 63, L-202 point 4, L-192 Q2-Q4) : UI_Displayed sans OpenButton, texte à la couleur de la rareté,
# réserve (Panel.Reserve, remote PlaceFromReserve, profil Reserve). Scénarios d a201 tels quels, sauf displayed (réécrit)
# et reserve (nouveau), ici ; prelude.luau d ici (celui d a191 + Controllers/UI/RarityFx). Arbre sans Config/Displayed :
# le lanceur d a201 tel quel.
# Banc hors Studio d'a201 (vague 61, L-192 : la récompense de zone de l'index n'est qu'un objet). Copie du banc
# a191 (même harnais, même prelude.luau d'a191-banc), avec ses scénarios :
#   config    Config/Index : un objet par zone (Item seul, objets d'a191 gardés), ZoneCash retiré, textes « +WRENCH »
#   reward    IndexService : réclamée = l'objet seul (ni argent, ni Vitesse, ni diamants, ni télémétrie), une fois ;
#             zone réclamée avant = l'objet une fois au chargement ; déjà versé par la vague 59 : rien de repris
#   v4        UI_Index_v4 avec Footer.ItemReward (RewardIcon, RewardCaption), CashReward et SpeedReward cachés
#   v4old     UI_Index_v4 sans ItemReward : sans erreur ; puis l'ancien UI_Index
#   off, diamonds, displayed : ceux d'a191, tels quels (a191-banc/tests.<nom>.luau)
# Repli : sans la marque d'a201 dans Config/Index (« L-192 »), relance le banc a191 tel quel.
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)"
A191="$N/a191-banc"
A55="$N/a117-banc/autres-bancs/a55-banc"
B="$A55/autres-bancs/a40-banc"
A53="$N/a53-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if [ ! -f "$ROOT/src/shared/Config/Displayed.luau" ]; then
	exec bash "$N/a201-banc/run.sh" "$@"
fi
if ! grep -q "L-192" "$ROOT/src/shared/Config/Index.luau" 2>/dev/null; then
	exec bash "$N/a201-banc/run.sh" "$@"
fi
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-config reward off diamonds displayed reserve v4 v4old a219 a219off a242 a255}"
LABEL="banc a191 (copies a255, a242, a219, a206 : inventaire, InventoryButton, réserve, présentoirs)"
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau server/Services/ContractChecker.luau server/Services/CosmeticService.luau server/Services/InventoryService.luau client/Controllers/IndexController.luau client/Controllers/DisplayedController.luau client/Controllers/UI/Motion.luau client/Controllers/UI/RarityFx.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	TESTS="$H/tests.$name.luau"
	if [ ! -f "$TESTS" ]; then TESTS="$N/a201-banc/tests.$name.luau"; fi
	if [ ! -f "$TESTS" ]; then TESTS="$A191/tests.$name.luau"; fi
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B/stubs.luau" "$B/ext29.luau" "$B/ext38.luau" "$B/stub-anticheat.luau" "$A53/ext51.luau"
		sources
		cat "$B/features.luau"
		if [ "$name" = "off" ]; then cat "$B/pre.off.luau"; else cat "$B/pre.on.luau"; fi
		cat "$B/setup.luau" "$A53/autres-bancs/compat51.luau" "$H/prelude.luau"
		case "$name" in a219*) cat "$H/a219-common.luau" ;; esac
		case "$name" in a242*) cat "$H/hide-reserve.luau" ;; *) cat "$H/show-reserve.luau" ;; esac
		cat "$TESTS"
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
