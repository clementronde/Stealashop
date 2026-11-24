#!/usr/bin/env bash
# Banc hors Studio d'a177 (2026-11-15, vague 55, Cantin : la porte des boutiques, joueur et bot).
# Scénarios :
#   owner : le propriétaire frappe à la batte le casseur de sa porte, dehors devant elle : 60 s sans frapper cette
#           porte ni voler cette boutique, message BreakerHit, un autre joueur pas touché, témoins (loin, plus de coup) ;
#           faux Roblox et mise en place du banc a32 (copie a37), comme le scénario combat d'a159 ;
#   bot   : le bot sort et frappe le casseur de sa porte (même interdiction), pas pendant le tuto ; mise en place du
#           banc a124 (copie a175, ses tests passés par A149_TESTS, comme a149 et a175) ;
#   panel : le panneau de repérage (PvPController) est devant la porte, côté rue, hors des Bounds ; faux Roblox du
#           banc a29 (copie a36) et aides de la copie a93 du banc a84, comme le scénario doors d'a159 ;
#   glass : porte en vitre Model (vantaux à montants opaques livrés en premier) : creux en verre transparent, cadre
#           visible ; casse : éclats et sons ; faux Roblox du banc a16 (copie a134) et faux GeometryService d'a44.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
# Avant la fusion d'a177 (pas de WindowService.IsBreaking) : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A29="$H/../a36-banc/autres-bancs/a29-banc"
A32="$H/../a37-banc/autres-bancs/a32-banc"
O84="$H/../a93-banc/autres-bancs/a84-banc"
A16="$H/../a134-banc/autres-bancs/a16"
A44="$H/../a44-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-owner bot panel glass}"
if ! grep -q "function WindowService.IsBreaking" "$SRC/server/Services/WindowService.luau" 2>/dev/null; then
	echo "banc a177 SAUTÉ : cet arbre n'a pas encore la porte des boutiques de la vague 55"
	echo "banc a177 (porte des boutiques : casseur, vitre, panneau) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES84="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau"
FILES32="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/TheftAlertService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/TheftAlertController.luau client/Controllers/BatController.luau client/Controllers/ShelfBoxController.luau"
FILES16="shared server/Services/WindowService.luau client/Controllers/WindowController.luau client/Controllers/ShatterController.luau client/Controllers/HitController.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	if [ "$name" = "bot" ]; then
		out=$(A149_TESTS="$H" bash "$H/../a175-banc/autres-bancs/a124/run.sh" "$ROOT" a177bot 2>&1)
		if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|arrêté" || true; fi
		line=$(printf '%s\n' "$out" | grep -E "^banc a124 .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
		if [ -z "$line" ]; then
			printf '%s\n' "$out" | tail -25
			echo "scénario bot : arrêté avant la fin"
			total_fails=$((total_fails + 1))
			continue
		fi
	else
		OUT="$OUTDIR/run.$name.luau"
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			if [ "$name" = "owner" ]; then
				cat "$A32/stubs.luau" "$A32/ext29.luau" "$A32/ext32.luau"
				cat "$A32/../stub-anticheat.luau"
				sources "$FILES32"
				cat "$A32/setup.luau"
			elif [ "$name" = "panel" ]; then
				cat "$A29/stubs.luau" "$A29/ext29.luau"
				cat "$A29/../stub-anticheat.luau"
				sources "$FILES84"
				cat "$O84/pre84.luau"
				cat "$A29/setup.luau"
				cat "$O84/lib84.luau"
			else
				cat "$A16/stubs.luau"
				cat "$A44/ext-carve.luau"
				sources "$FILES16"
				# Le début des scénarios d'a16 (faux Net, ToolService, assets, magasins, joueurs, aides), jusqu'au démarrage.
				awk '/^-+ démarrage/ { exit } { print }' "$A16/tests.luau"
			fi
			cat "$H/tests.$name.luau"
		} > "$OUT"
		out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
		line=$(printf '%s\n' "$out" | grep -E "^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
		if [ -z "$line" ]; then
			printf '%s\n' "$out" | tail -25
			echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
			total_fails=$((total_fails + 1))
			continue
		fi
		if [ "${VERBOSE:-}" = "1" ]; then
			printf '%s\n' "$out"
		else
			printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^  mesure" || true
		fi
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/; s/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a177 (porte des boutiques : casseur, vitre, panneau) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
