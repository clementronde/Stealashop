#!/usr/bin/env bash
# Modifiée par a87 (2026-11-11, demande de Cantin) : tests.heist attend AMB (premier morceau de la playlist, ou MUS_Ambient avant a87), défini par le setup de la copie a42.
# Copie d'a86 (2026-11-11, demande de Cantin) : fond unique MUS_Ambient → faux Roblox d'a42 pris dans la copie d'a86, tests.heist attend MUS_Ambient au lieu de MUS_Z2.
# Banc hors Studio d'a81 (2026-11-11, vague 26, L-097 point 8 : sons et musique livrés pas encore joués) :
#   heist : MUS_Heist tant qu'un chrono HeistTimer est affiché (après la poursuite, avant la zone) et Heist_Breath
#           en boucle avec elle (MusicController, HeistController réel).
#   truck : SFX_TruckArrive à l'apparition (attribut SpawnedAt), SFX_TruckBrake BrakeDelay s après, sur Root.
#   ui    : UI_Open / UI_Close sur les fenêtres (Motion.Open / Close), UI_Deny avec un Notify « Warning ».
#   gain  : Train_Gain avec chaque gain d'entraînement affiché (GainController).
# Faux Roblox : heist, truck et ui sur celui d'a42 (copie d'a71, avec ses pre/setup) ; gain sur celui d'a60 (copie d'a62).
# Avant la fusion (pas de HeistTrack dans Config/Music) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (heist truck ui gain)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)"
A="$N/a86-banc/autres-bancs/a42-banc" # a86 : copie avec MUS_Ambient
G="$N/a62-banc/autres-bancs/a60-banc"
ROOT="${1:-/f/StealAShop}"
# Avant la fusion d'a86 (pas de Music.AmbientTrack) : le banc d'origine, pour rester bon avant et après.
if ! grep -q AmbientTrack "$ROOT/src/shared/Config/Music.luau" 2>/dev/null; then exec bash "$H/../../../a81-banc/run.sh" "$@"; fi
shift || true
SRC="$ROOT/src"
if ! grep -q "HeistTrack" "$SRC/shared/Config/Music.luau" 2>/dev/null; then
	echo "banc a81 (sons et musique, L-097 point 8) : SAUTÉ (pas de HeistTrack dans Config/Music de $ROOT), 0 vérification(s), 0 échec(s)"
	exit 0
fi
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-heist truck ui gain}"
FILES_A42="shared client/Controllers/UI client/Controllers/ChaseController.luau client/Controllers/MusicController.luau client/Controllers/HeistController.luau client/Controllers/NotifyController.luau client/Controllers/ZoneGateController.luau client/Controllers/StoreInfoController.luau client/Controllers/TruckController.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/ContractChecker.luau"
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
			cat "$A/stubs.luau"
			sources "$FILES_A42"
			cat "$H/pre.$name.luau" "$A/setup.luau"
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
echo "banc a81 (sons et musique, L-097 point 8) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
