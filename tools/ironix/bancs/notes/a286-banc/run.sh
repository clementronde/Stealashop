#!/usr/bin/env bash
# Banc a286 (2026-11-21) : oublis côté code des demandes de Clément. Parties :
#   recompenses  harnais du banc a268/a266 (a53 copie a150, setup51, setup53, setup266), tests-recompenses.luau :
#                récompense du jour bloquée avant la fin du tuto (serveur et client), valeurs de Config d'a286 ;
#   pieges-new   harnais du banc a243/a268 (faux Roblox d'a29, lib84 et pre84 d'a84), pre-pieges.luau (Traps = true,
#                NewTraps = true), tests-pieges.luau : banane, filet, portique, trappe ; arrêt 1,5 s ; trappe = sortie
#                devant la porte et objet volé rendu ;
#   pieges-old   même harnais, NewTraps = false : l'ancienne disposition ;
#   complice     harnais du banc a202 (ouverture d'avant, vrai Shared/ItemWeight), pre-complice.luau (HeistPartnerBonus = true, doublure de
#                HubService), tests-complice.luau : prime à l'ami entré, rien aux autres ni sur un Fail ;
#   liste        harnais du banc a242 (copie a191), liste-common.luau, tests-liste.luau et tests-liste-vide.luau : UI_Displayed
#                en une seule liste (exposés puis réserve, boutons, PlaceFromReserve, ListEmpty).
# Arbre sans a286 (pas de Features.NewTraps) : SAUTÉ.
set -u
ME="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC0="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "NewTraps = " "$SRC0/shared/Config/Features.luau" 2>/dev/null; then
	echo "banc a286 : SAUTÉ (arbre sans Features.NewTraps)"
	exit 0
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
total=0; fails=0
run_one() { # $1 = fichier assemblé, $2 = nom
	local out line c f
	perl "$ME/../a265-banc/etape.pl" "$1" || { echo "partie $2 : etape.pl pas appliqué"; fails=$((fails + 1)); return; } # a265 : appels sans étape (harnais anciens), comme le lanceur commun
	if [ -n "${KEEP:-}" ]; then cp "$1" "$KEEP/"; fi
	out=$("$LUAU" "$(cygpath -w "$1")" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error" | head -20
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "partie $2 : arrêtée avant la fin"; fails=$((fails + 1)); return; fi
	echo "$line"
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
}
inline() { # $1 = racine, puis les chemins
	local root="$1"; shift
	(cd "$root" && find "$@" -name '*.luau' | sort) | awk -v root="$root" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
# --- récompenses (harnais a266, comme la partie lots d'a268)
B="$ME/../a150-banc/autres-bancs/a53-banc"
SRC="$SRC0"
if grep -q "ShelfOpen = true" "$SRC/shared/Config/Features.luau"; then
	cp -r "$SRC" "$TMP/src"; sed -i 's/ShelfOpen = true,/ShelfOpen = false,/' "$TMP/src/shared/Config/Features.luau"; SRC="$TMP/src"
fi
FILES="shared server/Services/QuestService.luau server/Services/WheelService.luau server/Services/Prize server/Services/RewardService.luau server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/RewardsController.luau client/Controllers/QuestController.luau client/Controllers/WheelController.luau client/Controllers/UI client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/Unbox"
{
	cat "$B/stubs.luau" "$B/ext29.luau" "$B/ext38.luau" "$B/ext46.luau" "$B/stub-anticheat.luau" "$B/ext51.luau" "$B/ext53.luau"
	inline "$SRC" $FILES
	cat "$B/features.luau" "$B/setup51.luau" "$B/setup53.luau" "$ME/../a266-banc/setup266.luau" "$ME/tests-recompenses.luau"
} > "$TMP/recompenses.luau"
run_one "$TMP/recompenses.luau" recompenses
# --- pièges (harnais a243)
A84="$ME/../a93-banc/autres-bancs/a84-banc"
A29="$ME/../a36-banc/autres-bancs/a29-banc"
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau server/Services/TrapService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau client/Controllers/TrapController.luau"
for mode in new old; do
	{
		echo 'SCENARIO = "on"'
		if [ "$mode" = new ]; then echo 'NEW_TRAPS = true'; else echo 'NEW_TRAPS = false'; fi
		awk '{ print } /^\t\tAnimationClipProvider = AnimationClipProvider,$/ { print "\t\tDebris = { AddItem = function() end },"; print "\t\tSoundService = { Name = \"SoundService\" }," }' "$A29/stubs.luau"
		cat "$A29/ext29.luau" "$A29/../stub-anticheat.luau"
		inline "$SRC0" $FILES
		cat "$ME/pre-pieges.luau" "$A84/pre84.luau" "$A29/setup.luau" "$A84/lib84.luau" "$ME/tests-pieges.luau"
	} > "$TMP/pieges-$mode.luau"
	run_one "$TMP/pieges-$mode.luau" "pieges-$mode"
done
# --- complice (harnais a202 : a30 d'a66, head d'a103 copie a114, levier-force et coups-en-rafale d'a134)
BASE="$ME/../a66-banc/autres-bancs/a30-banc"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
{
	cat "$BASE/stubs.luau" "$BASE/../stub-anticheat.luau"
	inline "$SRC0" $FILES
	cat "$ME/../a134-banc/levier-force.luau" "$ME/../a134-banc/coups-en-rafale.luau" "$ME/pre-complice.luau" "$BASE/setup.luau" "$ME/../a114-banc/autres-bancs/a103-banc/head.luau" "$ME/../a202-banc/head.luau" "$ME/tests-complice.luau"
} > "$TMP/complice.luau"
run_one "$TMP/complice.luau" complice
# --- liste unique d'UI_Displayed (harnais a191 copie a242 : a40 d'a55 copie a117, ext51 d'a53, compat51, prelude d'a242)
A242="$ME/../a242-banc/autres-bancs/a191"
B40="$ME/../a117-banc/autres-bancs/a55-banc/autres-bancs/a40-banc"
A53="$ME/../a53-banc"
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau server/Services/ContractChecker.luau server/Services/CosmeticService.luau server/Services/InventoryService.luau client/Controllers/IndexController.luau client/Controllers/DisplayedController.luau client/Controllers/UI/Motion.luau client/Controllers/UI/RarityFx.luau"
for part in liste liste-vide; do
	{
		cat "$B40/stubs.luau" "$B40/ext29.luau" "$B40/ext38.luau" "$B40/stub-anticheat.luau" "$A53/ext51.luau"
		inline "$SRC0" $FILES
		cat "$B40/features.luau" "$B40/pre.on.luau" "$B40/setup.luau" "$A53/autres-bancs/compat51.luau" "$A242/prelude.luau" "$A242/show-reserve.luau" "$ME/liste-common.luau" "$ME/tests-$part.luau"
	} > "$TMP/$part.luau"
	run_one "$TMP/$part.luau" "$part"
done
echo "banc a286 (jour après le tuto, Config, pièges BananaPeel et TrapDoor, prime au complice, liste unique) : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
