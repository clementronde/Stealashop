#!/usr/bin/env bash
# Banc a296 (2026-11-21) : nouveaux pièges allumés dans le jeu DEV seulement (Features.NewTrapsDev et
# Config/ProductIds.IsDev), coupés en PROD (Features.NewTraps = false). Harnais du banc a293, partie pièges (faux Roblox
# d'a29, lib84 et pre84 d'a84), pre-a296.luau et tests-pieges.luau (copie de celui d'a293), quatre parties :
#   dev     IsDev vrai                       : nouvelle disposition (colle, banane, portique, trappe) et ses effets ;
#   prod    IsDev faux                       : ancienne disposition (colle, filet, portique, colle) ;
#   absent  pas de Config/ProductIds         : ancienne disposition ;
#   studio  IsDev faux, attribut NewTrapsTest : nouvelle disposition.
# Arbre sans a296 (pas de Features.NewTrapsDev) : SAUTÉ.
set -u
ME="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC0="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "NewTrapsDev = true" "$SRC0/shared/Config/Features.luau" 2>/dev/null; then
	echo "banc a296 : SAUTÉ (arbre sans Features.NewTrapsDev = true)"
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
A84="$ME/../a93-banc/autres-bancs/a84-banc"
A29="$ME/../a36-banc/autres-bancs/a29-banc"
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau server/Services/TrapService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau client/Controllers/TrapController.luau"
for mode in dev prod absent studio; do
	{
		echo 'SCENARIO = "on"'
		echo "MODE = \"$mode\""
		case "$mode" in dev|studio) echo 'NEW_TRAPS = true' ;; *) echo 'NEW_TRAPS = false' ;; esac
		awk '{ print } /^\t\tAnimationClipProvider = AnimationClipProvider,$/ { print "\t\tDebris = { AddItem = function() end },"; print "\t\tSoundService = { Name = \"SoundService\" }," }' "$A29/stubs.luau"
		cat "$A29/ext29.luau" "$A29/../stub-anticheat.luau"
		inline "$SRC0" $FILES
		cat "$ME/pre-a296.luau" "$A84/pre84.luau" "$A29/setup.luau" "$A84/lib84.luau" "$ME/tests-pieges.luau"
	} > "$TMP/pieges-$mode.luau"
	run_one "$TMP/pieges-$mode.luau" "pieges-$mode"
done
echo "banc a296 (pièges : DEV nouvelle disposition, PROD et ProductIds absent ancienne, attribut NewTrapsTest nouvelle) : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
