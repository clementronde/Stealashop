#!/usr/bin/env bash
# Banc hors Studio d'a208 (vague 63, L-200 et L-204) : UI_RobuxShop_v2 (RobuxShopController), packs d'argent,
# boosts du HUD dans la boutique, caisse exclusive (Features.RobuxCrate, PolicyService), lueur d'achat.
# Faux Roblox et mise en place : ceux du banc a39 (a164-banc/autres-bancs/a39-banc : stubs.luau, ext29.luau,
# ext38.luau, setup.luau), lus sur place, sans copie ; ajouts dans common.luau (écran v2, PolicyService,
# fausse PurchaseGlow). Chaque scénario tourne dans son propre luau : stubs, ext, SOURCES, common, ses pre.*,
# setup, puis son tests.*.
#   v2         Config du dépôt (vitrine), v2 et ancien écran : sections, tri, couleurs, hauteurs, Featured,
#              minuteur, défilement, « Soon », fermeture
#   late       l'ancien écran seul, puis la v2 qui arrive, puis la v2 retirée
#   live       boutique ouverte : fenêtres d'achat, lueur, boosts et Id 0 en « Soon »
#   crate      caisse allumée et permise : chances, Count, OldPrice, OffersTab, « Soon »
#   restricted caisse allumée, ArePaidRandomItemsRestricted : cachée
#   policyfail caisse allumée, PolicyService en erreur : cachée
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A="$H/../a164-banc/autres-bancs/a39-banc"
ARG="${1:-/f/StealAShop}"
ROOT="${ARG%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-v2 late live crate restricted policyfail}"
if ! grep -q "UI_RobuxShop_v2" "$SRC/client/Controllers/RobuxShopController.luau" 2>/dev/null; then
	echo "banc a208 (boutique Robux v2) : SAUTÉ, pas de UI_RobuxShop_v2 dans RobuxShopController ($SRC, vague 63 pas encore fusionnée) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/RobuxShopController.luau client/Controllers/WeaponShopController.luau client/Controllers/AuraShopController.luau client/Controllers/RebirthController.luau client/Controllers/ShopPadController.luau server/Services/ContractChecker.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
pres() {
	case "$1" in
		live) echo "live" ;;
		crate) echo "live crate" ;;
		restricted) echo "live crate restricted" ;;
		policyfail) echo "live crate policyfail" ;;
		*) echo "" ;;
	esac
}
testsOf() {
	case "$1" in
		policyfail) echo "restricted" ;;
		*) echo "$1" ;;
	esac
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A/stubs.luau" "$A/ext29.luau" "$A/ext38.luau"
		sources
		cat "$H/common.luau"
		for pre in $(pres "$name"); do cat "$H/pre.$pre.luau"; done
		cat "$A/setup.luau"
		cat "$H/tests.$(testsOf "$name").luau"
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
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a208 (boutique Robux v2) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
