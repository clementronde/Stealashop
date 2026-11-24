#!/usr/bin/env bash
# Banc a293 (2026-11-21) : pièges allumés avec la colle gardée, prime au complice allumée. Parties (harnais d'a286) :
#   pieges-new   harnais du banc a243/a268 (faux Roblox d'a29, lib84 et pre84 d'a84), pre-pieges.luau (Traps = true,
#                NewTraps lu tel quel : doit être true), tests-pieges.luau : colle, banane, portique, trappe ;
#   pieges-old   même harnais, NewTraps = false : l'ancienne disposition ;
#   complice     harnais du banc a202, pre-complice.luau (HeistPartnerBonus lu tel quel : doit être true, doublure de
#                HubService), tests-complice.luau (copie de celui d'a286).
#   foule        crowd-run.sh (copie du banc a289, crowd-tests.luau avec A1 et A2) : marque « validé » de Config/Witness.Crowd.
# Arbre sans a293 (Features.NewTraps pas allumé) : SAUTÉ.
set -u
ME="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC0="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "NewTraps = true" "$SRC0/shared/Config/Features.luau" 2>/dev/null; then
	echo "banc a293 : SAUTÉ (arbre sans Features.NewTraps = true)"
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
# --- foule (crowd-run.sh, copie du banc a289 avec A1 et A2 : attrapé dans le magasin ou dans la rue)
out=$(timeout 300 bash "$ME/crowd-run.sh" "$ROOT" 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|arrêté" | head -20
line=$(printf '%s\n' "$out" | grep -E "^banc a293 crowd : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "partie foule : arrêtée avant la fin"; fails=$((fails + 1)); else
	echo "scénario a293 foule : ${line#banc a293 crowd : }"
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
fi
echo "banc a293 (pièges colle, banane, portique, trappe ; ancienne disposition ; prime au complice allumée ; foule attrapé dans le magasin ou dans la rue) : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
