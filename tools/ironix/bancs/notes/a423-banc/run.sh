#!/usr/bin/env bash
# Banc hors Studio d'a423 (Cantin, 24/11 : « le vigile tombe par terre dès qu'il commence à courir, puis se relève »).
# Cause relevée en Play : un Humanoid posé avec son HumanoidRootPart ancré passe en FallingDown à l'image suivante ;
# désancré au départ, il reste par terre et immobile ~3 s, puis GettingUp. Le faux Roblox reçoit ce comportement
# (etat-humanoide.luau : SetStateEnabled, GetStateEnabled, MoveTo sans effet en FallingDown).
#   garde  agent de la boutique (ShopDefenseService) sur le harnais du banc a408 (tests.garde.luau)
#   bot    avatar du bot (BotService) sur la copie a175 du banc a124, prélude d'a177 (tests.chute423bot.luau)
# Les deux échouent avant a423 (FallingDown permis à la pose) et passent après.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop, « garde bot ») ; VERBOSE=1 : toute la sortie
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$(cd "$H/.." && pwd)"
A408="$B/a408-banc"
A84="$B/a93-banc/autres-bancs/a84-banc"
A29="$B/a36-banc/autres-bancs/a29-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-garde bot}"
total_c=0
total_f=0
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
count() { # $1 = sortie, $2 = nom du scénario
	local line c f
	line=$(printf '%s\n' "$1" | grep -E "^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$1" | tail -20
		echo "  $2 : arrêté avant la fin (erreur ci-dessus)"
		total_f=$((total_f + 1))
		return
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$1"; else printf '%s\n' "$1" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/^(scénario .* : )?([0-9]+) vérification.*/\2/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $2 : $c contrôles, $f raté(s)"
	total_c=$((total_c + c))
	total_f=$((total_f + f))
}
for name in $SCENARIOS; do
	case "$name" in
	garde)
		if [ ! -f "$SRC/shared/Config/ShopDefense.luau" ]; then
			echo "  garde : SAUTÉ (pas de Config/ShopDefense, a408 pas encore fusionné)"
			continue
		fi
		FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau server/Services/ShopDefenseService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau"
		OUT="$OUTDIR/run.garde.luau"
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			echo 'SCENARIO = "on"'
			awk '{ print } /^\t\tAnimationClipProvider = AnimationClipProvider,$/ { print "\t\tDebris = { AddItem = function() end },"; print "\t\tSoundService = { Name = \"SoundService\" }," }' "$A29/stubs.luau"
			cat "$A29/ext29.luau"
			cat "$A29/../stub-anticheat.luau"
			(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
			cat "$A408/pre.luau"
			cat "$A84/pre84.luau"
			cat "$A29/setup.luau"
			cat "$A84/lib84.luau"
			cat "$H/etat-humanoide.luau"
			cat "$H/tests.garde.luau"
		} > "$OUT"
		count "$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)" garde
		;;
	bot)
		if ! grep -q "BOT_DOOR_GROUP" "$SRC/server/Services/BotService.luau" 2>/dev/null; then
			echo "  bot : SAUTÉ (BotService d'avant a261)"
			continue
		fi
		TESTS_DIR="$OUTDIR/tests-bot"
		mkdir -p "$TESTS_DIR"
		cat "$B/a177-banc/autres-bancs/a124/prelude.luau" "$H/etat-humanoide.luau" "$H/tests.chute423bot.luau" > "$TESTS_DIR/tests.chute423bot.luau"
		out=$(A149_TESTS="$TESTS_DIR" VERBOSE=1 bash "$B/a175-banc/autres-bancs/a124/run.sh" "$ROOT" chute423bot 2>&1)
		count "$out" bot
		;;
	*)
		echo "  $name : scénario inconnu"
		total_f=$((total_f + 1))
		;;
	esac
done
echo "banc a423 (agent de la boutique et bot qui partent sans tomber) : $total_c vérification(s), $total_f échec(s)"
exit $((total_f > 0))
