#!/usr/bin/env bash
# Banc hors Studio d'a127 (2026-11-14, vague 38, réponses de Clément L-137 points 1 et 3, L-135 point 5).
#   walls  Stage_3/Walls suit la tuile Walls à tous les niveaux de la boutique (copie à part dans SkillVisuals sous
#          le niveau 3) ; Stage_5/Security et Stage_5/Alarm suivent Cameras 1. Harnais du banc vis-competences
#          (copie a93 du banc a84, faux Roblox et mise en place d'a29, lus sur place) plus le vrai ShopStageService.
#   drop   objet NPCItem lâché (G) ou tombé (batte) dans son magasin : il revole sur son rayon ; rue, autre
#          magasin, objet volé : rien ne change. Harnais du banc a114 (a30 copie a66, head a103 copie a114).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop ; scénarios : walls drop)
# Arbre sans PlotVisuals.Walls ou sans SetBackToShelfCheck : le scénario est « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a127 (murs, digicode, objet lâché dans son magasin)"
SCENARIOS="${*:-walls drop}"
A84="$H/../a93-banc/autres-bancs/a84-banc"
A29="$H/../a36-banc/autres-bancs/a29-banc"
A30="$H/../a66-banc/autres-bancs/a30-banc"
HEAD="$H/../a114-banc/autres-bancs/a103-banc/head.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
build_walls() {
	cat "$A29/stubs.luau" "$A29/ext29.luau"
	cat "$A29/../stub-anticheat.luau"
	sources "shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau server/Services/ShopStageService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau"
	cat "$A84/pre84.luau"
	cat "$A29/setup.luau"
	cat "$A84/lib84.luau"
	cat "$H/tests.walls.luau"
}
build_drop() {
	cat "$A30/stubs.luau"
	cat "$A30/../stub-anticheat.luau"
	sources "shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
	cat "$A30/setup.luau"
	cat "$HEAD"
	cat "$H/tests.drop.luau"
}
skip() {
	case "$1" in
		walls) ! grep -q "EveryStage" "$SRC/shared/Config/SkillTree.luau" 2>/dev/null ;;
		drop) ! grep -q "SetBackToShelfCheck" "$SRC/server/Services/CarryService.luau" 2>/dev/null ;;
	esac
}

total_checks=0
total_fails=0
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
for name in $SCENARIOS; do
	if skip "$name"; then
		echo "  $name : SAUTÉ (arbre d'avant a127)"
		continue
	fi
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		"build_$name"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
