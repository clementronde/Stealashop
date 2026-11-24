#!/usr/bin/env bash
# Banc hors Studio d'a191 (2026-11-15, vague 59 ; L-182 points 6, 10, 12 ; L-183) :
#   config    Config/Index : récompenses fixes de zone (argent, Vitesse, objet), textes, icônes, PageSize
#   reward    IndexService : réclamée une seule fois (prime, Vitesse de la stat, arme ou aura donnée), plus de
#             +5 % ni de +3 %, zone réclamée avant la vague 59 (Vitesse et objet au chargement, sans prime),
#             objet déjà possédé, carnet IndexGifts abîmé
#   off       Features.Index = false : ni récompense, ni rattrapage au chargement
#   diamonds  Diamonds = 0 au gabarit, profil sans Diamonds, DataService.GetDiamonds (valeurs invalides)
#   displayed DisplayedController + vrai serveur : panneau des exposés, « Exposer les meilleurs » (EquipBest :
#             présentoirs pleins, objets moins bons, rien possédé, appels répétés), RemoveButton, OpenButton
#   v4        IndexController sur UI_Index_v4 (onglets, pages 4 × 2, façade, récompense, pastilles, réclamation),
#             avant l'ancien UI_Index, qui reste lu sans la v4
# Faux Roblox, mise en place et bouchons : ceux du banc a55 copie a117 (a117-banc/autres-bancs/a55-banc :
# autres-bancs/a40-banc, ext51 et compat51 d'a53), plus prelude.luau (CosmeticService, InventoryService,
# DisplayedController montés). Vrais : IndexService, DataService, DisplayService, InventoryService,
# CosmeticService, ToolService, StatsService…, IndexController, DisplayedController, UI/Motion et tout Shared.
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
A55="$N/a117-banc/autres-bancs/a55-banc"
B="$A55/autres-bancs/a40-banc"
A53="$N/a53-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-config reward off diamonds displayed v4}"
LABEL="banc a191 (objets exposés, index v4, récompenses fixes, diamants)"
if ! grep -q "ZoneRewards = ZONE_REWARDS" "$SRC/shared/Config/Index.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, pas de ZoneRewards dans Config/Index (a191 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau server/Services/ContractChecker.luau server/Services/CosmeticService.luau server/Services/InventoryService.luau client/Controllers/IndexController.luau client/Controllers/DisplayedController.luau client/Controllers/UI/Motion.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B/stubs.luau" "$B/ext29.luau" "$B/ext38.luau" "$B/stub-anticheat.luau" "$A53/ext51.luau"
		sources
		cat "$B/features.luau"
		if [ "$name" = "off" ]; then cat "$B/pre.off.luau"; else cat "$B/pre.on.luau"; fi
		cat "$B/setup.luau" "$A53/autres-bancs/compat51.luau" "$H/prelude.luau"
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
