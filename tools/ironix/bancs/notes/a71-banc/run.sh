#!/usr/bin/env bash
# Banc hors Studio d'a71 (2026-11-11, vague 24, retours du Play de Cantin) :
#   chase : sons du départ espacés (Heist_Grab, Chase_Whistle à WhistleDelay, Chase_Siren à SirenDelay, MUS_Chase à
#           MusicDelay), poursuite courte sans sirène ni musique, bulle BB_GuardShout entière (Bubble, Tail et Bang
#           ensemble à chaque image), UI_HUD.LeftRailTouch caché puis remis (aussi s'il était déjà caché).
#           Faux Roblox et mise en place : copie d'a71 du banc a68 (autres-bancs/a68-banc, avec ../a42-banc).
#   gain  : BB_Gain, attributs SpeedColor/PowerColor/CashColor et SpeedIcon/PowerIcon/CashIcon lus en priorité,
#           repli sur Config/UiMotion et l'icône du HUD. Faux Roblox : la copie d'a62 du banc a60.
# Avant la fusion (pas de SirenDelay dans Config/ChaseFeel) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (chase gain)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
F="$H/autres-bancs/a68-banc"
A="$H/autres-bancs/a42-banc"
G="$N/a62-banc/autres-bancs/a60-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
if ! grep -q "SirenDelay" "$SRC/shared/Config/ChaseFeel.luau" 2>/dev/null; then
	echo "banc a71 (sons, bulle, LeftRailTouch, BB_Gain) : SAUTÉ (pas de SirenDelay dans Config/ChaseFeel de $ROOT), 0 vérification(s), 0 échec(s)"
	exit 0
fi
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-chase gain}"
FILES_CHASE="shared client/Controllers/UI client/Controllers/ChaseFeelController.luau client/Controllers/ChaseController.luau client/Controllers/MusicController.luau client/Controllers/NotifyController.luau client/Controllers/ZoneGateController.luau client/Controllers/StoreInfoController.luau client/Controllers/TruckController.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/ContractChecker.luau"
FILES_GAIN="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	if [ "$name" = "gain" ]; then
		{
			cat "$G/stubs.luau" "$G/ext-motion.luau" "$G/ext-a60.luau"
			sources "$FILES_GAIN"
			cat "$G/setup.luau" "$G/setup-a60.luau"
			cat "$H/tests.gain.luau"
		} > "$OUT"
	else
		{
			cat "$F/stubs.luau"
			sources "$FILES_CHASE"
			cat "$F/pre.feel.luau" "$A/setup.luau" "$F/common.luau"
			cat "$H/tests.$name.luau"
		} > "$OUT"
	fi
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "([0-9]+) vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | grep -oE '[0-9]+ vérification' | grep -oE '[0-9]+')
	f=$(printf '%s' "$line" | grep -oE '[0-9]+ échec' | grep -oE '[0-9]+')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a71 (sons, bulle, LeftRailTouch, BB_Gain) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
