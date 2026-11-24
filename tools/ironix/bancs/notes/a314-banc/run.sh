#!/usr/bin/env bash
# Banc a314 (2026-11-23, L-292, L-271) : vendre un objet depuis l'écran Display, avec la confirmation YES / NO.
# Harnais de la partie « liste » d'a286 (a191 copie a242 : a40 d'a55 copie a117, ext51 d'a53, compat51, prelude d'a242),
# plus PawnShopService monté, et l'écran UI_Displayed de la maquette de Clément (tools/clement/ui_displayed_v2.luau :
# Template.Buttons.SellButton, Dock.Confirm). Parties :
#   vente     tests-vente.luau : objet exposé et objet de la réserve vendus (argent versé = prix du receleur, objet
#             retiré, présentoir libéré), prix affiché = prix vendu, NO / CloseButton / fermeture sans effet, double
#             demande = une seule vente, objet d'un autre joueur et objet inconnu refusés, objet sous antivol pas
#             encore posé (règle du receleur : vendable), objet tenu par un voleur refusé, contrat (noms facultatifs,
#             UI_Displayed une seule fois).
# Arbre sans a314 (pas de remote DisplayedSell) : SAUTÉ.
set -u
ME="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC0="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q '"DisplayedSell"' "$SRC0/shared/Net/Definitions.luau" 2>/dev/null; then
	echo "banc a314 : SAUTÉ (arbre sans le remote DisplayedSell)"
	exit 0
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
total=0; fails=0
run_one() { # $1 = fichier assemblé, $2 = nom
	local out line c f
	perl "$ME/../a265-banc/etape.pl" "$1" || { echo "partie $2 : etape.pl pas appliqué"; fails=$((fails + 1)); return; }
	if [ -n "${KEEP:-}" ]; then cp "$1" "$KEEP/"; fi
	out=$("$LUAU" "$(cygpath -w "$1")" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error" | head -30
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "partie $2 : arrêtée avant la fin"; fails=$((fails + 1)); return; fi
	echo "$line"
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
}
inline() { # $1 = racine, puis les chemins
	local root="$1"; shift
	(cd "$root" && find "$@" -name '*.luau' | sort) | awk -v root="$root" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
A242="$ME/../a242-banc/autres-bancs/a191"
B40="$ME/../a117-banc/autres-bancs/a55-banc/autres-bancs/a40-banc"
A53="$ME/../a53-banc"
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau server/Services/ContractChecker.luau server/Services/CosmeticService.luau server/Services/InventoryService.luau server/Services/PawnShopService.luau client/Controllers/IndexController.luau client/Controllers/DisplayedController.luau client/Controllers/UI/Motion.luau client/Controllers/UI/RarityFx.luau"
for part in vente; do
	{
		cat "$B40/stubs.luau" "$B40/ext29.luau" "$B40/ext38.luau" "$B40/stub-anticheat.luau" "$A53/ext51.luau"
		inline "$SRC0" $FILES
		cat "$B40/features.luau" "$B40/pre.on.luau" "$B40/setup.luau" "$A53/autres-bancs/compat51.luau" "$A242/prelude.luau" "$A242/show-reserve.luau" "$ME/ecran.luau" "$ME/tests-$part.luau"
	} > "$TMP/$part.luau"
	run_one "$TMP/$part.luau" "$part"
done
echo "banc a314 (vente depuis l'écran Display, confirmation YES / NO) : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
