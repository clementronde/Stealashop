#!/usr/bin/env bash
# Banc hors Studio d a190 (vague 59, L-182 points 4, 5, 7, 8 ; L-183 UI_HUD) : nouveau HUD.
#   spent    décompte de l argent après un achat (Config/Hud.CashSpent, Quint Out ~1,9 s), CashSpent « -$X »
#            additionné, caché à la fin ; une hausse garde le défilement court ; ancien HUD sans CashSpent
#   pieces   tapis : 5 morceaux « +0.4 Speed » sur la seconde, même total, chacun vit 0,75 s, pulsation de SpeedRow
#            de × 1,1 à × 1,4 ; « ×2 » en exposant d a178 gardé ; Pieces = 1 : l ancien « +2 Speed/s »
#   menu     ancien HUD (rien ne casse) ; nouveau HUD : menu ouvert et fermé, refermé au choix d un bouton,
#            MenuAlert, DisplayedButton → DisplayedController, boutons en situation montrés et cachés, prix,
#            recharge, « Soon », aucun achat ; rebranchement sans connexion qui reste
#   contract inventaire archivé (UI_Inventory facultatif, InventoryButton sorti, en note), nouveaux noms facultatifs
# Faux Roblox : celui du banc a60 (copie a134 : stubs, ext-motion, ext-a60, setup, setup-a60), lu sur place.
# Sur un arbre sans Config/Hud.luau (avant a190) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-spent pieces pieces1 menu contract}"
A60="$H/../a134-banc/autres-bancs/a60"
if [ ! -f "$SRC/shared/Config/Hud.luau" ]; then
	echo "banc a190 (nouveau HUD) : SAUTÉ, a190 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/HudMenuController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A60/stubs.luau"
		sed -E -f "$H/patches/quint.sed" "$A60/ext-motion.luau" # Quint Out (décompte de Cash) ajouté au faux TweenService
		cat "$A60/ext-a60.luau" "$H/../a155-banc/ext-tohex.luau"
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$A60/setup.luau" "$A60/setup-a60.luau" "$H/setup190.luau" "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a190 (nouveau HUD) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
