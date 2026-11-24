#!/usr/bin/env bash
# Banc hors Studio d'a159 (2026-11-14, vague 50, L-163 : n'importe qui peut braquer n'importe qui).
# Scénarios :
#   doors  : porte d'une boutique en coups (PvP.DoorHits = 40, un coup = 1 quelle que soit la force), plafond de
#            PvP.DoorMaxHitsPerSecond (8) coups comptés par seconde tous voleurs confondus, temps seul et à quatre
#            (sans et avec réparation), Reinforced Door (+8 par niveau, 80 au plus), Door Repair en coups, Walls
#            sans effet, panneau « 7/40 » ;
#   lock   : verrou (tuile Curtain, remote LockShop) : 30 s offertes, 45 et 60 s achetées, coups ignorés,
#            refus (déjà verrouillée, recharge de 120 s, porte cassée), levée à la fin ;
#   combat : combat égal à la batte (même étourdissement, aucun dégât, quelle que soit la force).
# doors et lock : faux Roblox et mise en place du banc a29 (copie a36) et aides de la copie a93 du banc a84,
# lus sur place ; combat : ceux du banc a32 (copie a37), comme le banc a99.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
# Avant la fusion d'a159 (pas de PvP.DoorHits) : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A29="$H/../a36-banc/autres-bancs/a29-banc"
A32="$H/../a37-banc/autres-bancs/a32-banc"
O84="$H/../a93-banc/autres-bancs/a84-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-doors lock combat}"
if ! grep -q "DoorHits = " "$SRC/shared/Config/PvP.luau" 2>/dev/null; then
	echo "banc a159 SAUTÉ : cet arbre n'a pas encore les portes en coups (L-163)"
	echo "banc a159 (portes en coups, verrou, combat égal) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES84="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau"
FILES32="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/TheftAlertService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/TheftAlertController.luau client/Controllers/BatController.luau client/Controllers/ShelfBoxController.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		if [ "$name" = "combat" ]; then
			cat "$A32/stubs.luau" "$A32/ext29.luau" "$A32/ext32.luau"
			cat "$A32/../stub-anticheat.luau"
			sources "$FILES32"
			cat "$A32/setup.luau"
		else
			cat "$A29/stubs.luau" "$A29/ext29.luau"
			cat "$A29/../stub-anticheat.luau"
			sources "$FILES84"
			cat "$O84/pre84.luau"
			cat "$A29/setup.luau"
			cat "$O84/lib84.luau"
		fi
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    |^  mesure" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a159 (portes en coups, verrou, combat égal) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
