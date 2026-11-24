#!/usr/bin/env bash
# a232 (vague 70) : copie du banc a215 avec le faux Roblox d a232 (TextWrapped = false remet TextScaled à false ; coupure aux seules espaces ASCII ; checkLine : TextScaled gardé) ; B8a lit le texte par PLAIN (espaces insécables).
# Banc hors Studio d'a215 (vague 65, restes de fusion58) : le gain qui vole, lisible, et le bon texte pour une bulle.
#   layout   repli sans UI_HUD.TrainGainFly.Template : « +8 Speed/s » sur UNE ligne à la hauteur du cadre (élargi), exposant
#            « ×3 » / « ×1.5 » juste après le nombre sans le couvrir ni la suite, à 1920 × 1080, 844 × 390 et 1280 × 720 ;
#            « +X » sur place (VfxEnabled = false) avec exposant ; modèle de Clément inchangé
#   bubble   NoteBubble puis hausse de Speed : « +32 Speed » (sans « /s ») ; tapis « +8 Speed/s » inchangé ; bulle et seconde
#            du tapis dans la même hausse : deux textes, même total ; annonce trop vieille oubliée ; sur place ; trail
#   order    (serveur, harnais d'a214) BubbleGone « Claimed » envoyé avant la hausse de Speed
# Faux Roblox : celui du banc a213 (lu sur place) + setup215.luau (mesure du texte : TextService, TextBounds, TextWrapped).
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : lignes ok
set -u
H0="$(cd "$(dirname "$0")" && pwd)"; B="$(cd "$H0/../../.." && pwd)"; H="$B/a215-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-layout bubble order}"
: # B fixé plus haut
A60="$B/a134-banc/autres-bancs/a60"
A190="$B/a205-banc/autres-bancs/a190"
A213="$B/a213-banc"
if ! grep -q "BubbleGain" "$SRC/shared/Config/Hud.luau" 2>/dev/null; then
	echo "banc a215 (gain qui vole, texte de bulle) : SAUTÉ, a215 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/HudMenuController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
SFILES="server/Services/TrainingService.luau shared/TrainingZone.luau server/Services/MachineVariantService.luau shared/Config/Training.luau shared/Config/Upgrades.luau shared/Config/DeepFreeze.luau shared/Net/RateLimiter.luau shared/Config/Bubbles.luau server/Services/BubbleService.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	if [ "$name" = "order" ]; then
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
			echo 'SCENARIO = "none"'
			echo "SOURCES = {}"
			printf '%s\n' $SFILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
			cat "$B/a134-banc/autres-bancs/a65/harness.luau"
			grep -v '^print(`banc a214' "$B/a214-banc/tests.bubbles.luau"
			cat "$H/tests.order.luau"
		} > "$OUT"
		pattern="^banc a215 .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	else
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$A60/stubs.luau"
			sed -E -f "$A190/patches/quint.sed" "$A60/ext-motion.luau"
			cat "$A60/ext-a60.luau" "$B/a155-banc/ext-tohex.luau"
			sources
			cat "$A60/setup.luau" "$A60/setup-a60.luau" "$A190/setup190.luau" "$A213/setup213.luau" "$H/setup215.luau" "$B/a232-banc/setup232.luau"; sed -e "s/string.match(amount.Text, /string.match(PLAIN(amount.Text), /" "$H/tests.$name.luau"
		} > "$OUT"
		pattern="^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	fi
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "$pattern" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|échoue|ÉCHOUÉ" || true
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a215 (gain qui vole, texte de bulle) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
