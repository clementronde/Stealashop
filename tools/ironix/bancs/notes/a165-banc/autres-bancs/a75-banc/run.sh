#!/usr/bin/env bash
# Copie a165 (2026-11-14, vague 51) : escapeFov part du champ de vision actuel (E2b : plus de retour d'un coup à 70) et
# resetEscape remet l'image de BoxIcon (E1t sans exception pour l'icône, E2c : image de Clément). Arbre sans a165
# (pas de « images = {} » dans UiFeelController) : la copie a85 telle quelle.
_A165_R="${1:-/f/StealAShop}"
if ! grep -q "images = {}" "$_A165_R/src/client/Controllers/UiFeelController.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a85-banc/autres-bancs/a75-banc/run.sh" "$@"; fi
# Copie d'a85 (2026-11-11, vague 27, L-096 point 2), faite sur la copie d'a79 : UI.Twins.UI_HUD.Names a un 5e bouton,
# SkillTreeButton (bouton « Upgrades » de l'arbre de compétences) → le contrôle « les 4 boutons de la colonne »
# devient « les 4 boutons, ou 5 avec SkillTreeButton » (twins). Sans relance : bon avant et après la fusion d'a85.
# Copie d'a79 (2026-11-11, L-097 point 3), faite sur la copie d'a76 (E0e : BoxSecured après SaveSettings, plus forcément dernier) : BoxSecured a un 2e argument facultatif (rarity, icône ICON_BOX_<Rareté>) → E0d accepte tier seul ou tier + rarity? ; E3r : icône de la rareté (seulement si le remote a rarity). Sans relance : bonne avant et après les fusions d'a76 et d'a79.
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
