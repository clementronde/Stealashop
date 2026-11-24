#!/usr/bin/env bash
# Banc hors Studio d'a254 (vague 73, L-240 point 3 : annonces au serveur dans UI_Announce), sur le harnais du banc
# a239 (a30 + a103, vrai StoreHeistService, magasins de zones 4 et 5) :
#   night  Config/Announce.Enabled = true : remote Announce (RichText, detail, icône, texte sans balises) la nuit et le
#          jour (Mythique et plus), Shared/Announce.steal et serverLuck, plus de Notify ;
#   off    Enabled = false dans le fichier assemblé : Notify comme avant, ni annonce de jour ni de vol.
#   bash run.sh [racine du dépôt]
# Avant a254 (pas de Config/Announce) : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
S="$H/.."
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a254 (annonces au serveur, UI_Announce)"
if ! grep -q "DayBoxMinRarity" "$SRC/shared/Config/Announce.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (avant a254) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
BASE="$S/a66-banc/autres-bancs/a30-banc"
{
	cat "$BASE/stubs.luau" "$BASE/../stub-anticheat.luau"
	sources "shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
	cat "$BASE/setup.luau" "$S/a103-banc/head.luau" "$H/tests.a254.luau"
} > "$T/night.luau"
{
	printf 'ANNOUNCE_OFF = true\n'
	sed "s/Enabled = true, -- interrupteur ; false = comme avant/Enabled = false, -- interrupteur ; false = comme avant/" "$T/night.luau"
} > "$T/off.luau"
checks=0
fails=0
for name in night off; do
	out=$("$LUAU" "$(cygpath -w "$T/$name.luau")" 2>&1)
	printf '%s\n' "$out" | grep -E "MESURE|ÉCHEC|ERREUR" || true
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -20
		echo "  $name : arrêté avant la fin"
		fails=$((fails + 1))
		continue
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	checks=$((checks + c))
	fails=$((fails + f))
done
# Points d appel (texte des services, pas requis par ce harnais).
for pair in "PvPService:Announce.steal(thief, victim, theft.ItemId" "MonetizationService:Announce.serverLuck(player, multiplier, minutes" "StoreHeistService:Announce.boxes(best.Rarity"; do
	checks=$((checks + 1))
	if ! grep -qF "${pair#*:}" "$SRC/server/Services/${pair%%:*}.luau"; then
		echo "ÉCHEC point d appel absent : $pair"
		fails=$((fails + 1))
	fi
done
echo "$LABEL : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
