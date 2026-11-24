#!/usr/bin/env bash
# Copie d'a76 (2026-11-11, vague 25) : SetHotbar ajouté à la fin de Net/Definitions après BoxSecured →
# E0e (tests.escape.luau) vérifie que BoxSecured vient après SaveSettings (vague 23), plus qu'il est le dernier.
# Sur un arbre sans src/shared/HotbarLayout.luau : relance le banc a75 tel quel.
# Banc hors Studio d'a75 (vague 24, 2026-11-11) : L-095 points 3 et 4, L-094, L-099 point 1.
#   toast  : messages du bas dans UI_Toast (3 au plus, vert pour Success, blanc sinon, pop, 2,4 s,
#            effacement), repli UI_Notify puis NotifyV0 (NotifyController) ;
#   escape : arrivée en zone safe (UiFeelController.Escape, remote BoxSecured) : Flash, Banner, Title,
#            BoxIcon = ICON_BOX_<Tier>, sons Heist_SafeFlash puis Heist_Escape, champ de vision 70 → 82 → 70,
#            pendant et hors poursuite ; rien n'est laissé ;
#   open   : valeurs Open, OpenStagger, Close, Swap, Hover… de Config/UiMotion (tableau de Clément) ;
#            cartes une à une à l'ouverture (Motion.Open), fermeture, changement d'onglet (Motion.Swap) ;
#   twins  : boutons de UI_HUD.LeftRail ET LeftRailTouch branchés (RobuxShopController, RebirthController,
#            HudController), ContractChecker sans ligne pour ces doublons voulus (UI.Twins), UI_Toast et
#            UI_Escape facultatifs au contrat.
# Faux Roblox : toast, escape, open sur la copie d'a62 du banc a60 (a62-banc/autres-bancs/a60-banc),
# complétée par ext-a75.luau (Decal) ; twins sur la copie d'a62 du banc a39 (a62-banc/autres-bancs/a39-banc).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B60="$H/../../../a62-banc/autres-bancs/a60-banc"
B39="$H/../../../a62-banc/autres-bancs/a39-banc"
ROOT="${1:-/f/StealAShop}"
if [ ! -f "$ROOT/src/shared/HotbarLayout.luau" ]; then
	exec bash "$H/../../../a75-banc/run.sh" "$@"
fi
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-toast escape open twins}"
if ! grep -q "OpenStagger" "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "banc a75 (Toast, Escape, ouverture des écrans, boutons en double) : SAUTÉ, pas d'OpenStagger dans Config/UiMotion de $SRC (vague 24 pas encore fusionnée) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES60="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau client/Controllers/NotifyController.luau"
FILES39="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/RobuxShopController.luau client/Controllers/WeaponShopController.luau client/Controllers/AuraShopController.luau client/Controllers/RebirthController.luau client/Controllers/ShopPadController.luau server/Services/ContractChecker.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	if [ "$name" = "twins" ]; then
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$B39/stubs.luau" "$B39/ext29.luau" "$B39/ext38.luau"
			sources "$FILES39"
			cat "$B39/setup.luau" "$H/tests.$name.luau"
		} > "$OUT"
	else
		{
			cat "$B60/stubs.luau" "$B60/ext-motion.luau" "$B60/ext-a60.luau" "$H/ext-a75.luau"
			sources "$FILES60"
			cat "$B60/setup.luau" "$B60/setup-a60.luau" "$H/setup-a75.luau" "$H/tests.$name.luau"
		} > "$OUT"
	fi
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
	c=$(printf '%s' "$line" | sed -E 's/^(scénario .* : )?([0-9]+) vérification.*/\2/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a75 (Toast, Escape, ouverture des écrans, boutons en double) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
