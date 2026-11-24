#!/usr/bin/env bash
# Banc a268 (vague 81, 2026-11-20) : lots « colis d'une rareté » donnés partout (Prize/Grant → UnboxService.GiveBoxRarityItem,
# plancher à la rareté du colis), coffre de la semaine jamais sous Épique, pièges pris quand on les traverse entre deux
# contrôles (TrapService : trajet testé). Deux parties :
#   lots     harnais du banc a266 (a53 copie a150, setup51, setup53, setup266), tests-lots.luau ;
#   pieges   harnais du banc a243 (copie a267 : faux Roblox d'a29, lib84 et pre84 d'a84), pre-pieges.luau (Traps = true),
#            tests-pieges.luau.
# Arbre sans Traps.SweepMax (avant a268) : les deux parties tournent quand même (cas qui échouent sur l'ancien code).
set -u
ME="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC0="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
total=0; fails=0
run_one() { # $1 = fichier assemblé, $2 = nom
	local out line c f
	out=$("$LUAU" "$(cygpath -w "$1")" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error" | head -20
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "partie $2 : arrêtée avant la fin"; fails=$((fails + 1)); return; fi
	echo "$line"
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
}
# --- lots (harnais a266)
B="$ME/../a150-banc/autres-bancs/a53-banc"
SRC="$SRC0"
if grep -q "ShelfOpen = true" "$SRC/shared/Config/Features.luau"; then
	cp -r "$SRC" "$TMP/src"; sed -i 's/ShelfOpen = true,/ShelfOpen = false,/' "$TMP/src/shared/Config/Features.luau"; SRC="$TMP/src"
fi
FILES="shared server/Services/QuestService.luau server/Services/WheelService.luau server/Services/Prize server/Services/RewardService.luau server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/RewardsController.luau client/Controllers/QuestController.luau client/Controllers/WheelController.luau client/Controllers/UI client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/Unbox"
{
	cat "$B/stubs.luau" "$B/ext29.luau" "$B/ext38.luau" "$B/ext46.luau" "$B/stub-anticheat.luau" "$B/ext51.luau" "$B/ext53.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B/features.luau" "$B/setup51.luau" "$B/setup53.luau" "$ME/../a266-banc/setup266.luau" "$ME/tests-lots.luau"
} > "$TMP/lots.luau"
run_one "$TMP/lots.luau" lots
# --- pièges (harnais a243)
A84="$ME/../a93-banc/autres-bancs/a84-banc"
A29="$ME/../a36-banc/autres-bancs/a29-banc"
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau server/Services/TrapService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau client/Controllers/TrapController.luau"
{
	echo 'SCENARIO = "on"'
	awk '{ print } /^\t\tAnimationClipProvider = AnimationClipProvider,$/ { print "\t\tDebris = { AddItem = function() end },"; print "\t\tSoundService = { Name = \"SoundService\" }," }' "$A29/stubs.luau"
	cat "$A29/ext29.luau" "$A29/../stub-anticheat.luau"
	(cd "$SRC0" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC0" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$ME/pre-pieges.luau" "$A84/pre84.luau" "$A29/setup.luau" "$A84/lib84.luau" "$ME/tests-pieges.luau"
} > "$TMP/pieges.luau"
run_one "$TMP/pieges.luau" pieges
echo "banc a268 (lots de rareté, coffre Épique, pièges traversés) : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
