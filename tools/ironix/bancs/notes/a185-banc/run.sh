#!/usr/bin/env bash
# Banc hors Studio d'a185 (2026-11-15, vague 58) :
#   order : L-174, ordre d'attribution des parcelles par l'attribut AssignOrder (avec, sans, invalide ; place libérée
#           reprise ; bot sur la dernière dans l'ordre d'attribution) ;
#   panel : L-169 Q6, BB_ShopInfo de Clément copié par PvPController (HP dans HPLine, Status en pastille cadre + texte) :
#           Status caché, « LOCKED 23s », « OPEN », « ROB AGAIN IN 42s », puis caché de nouveau.
# Faux Roblox du banc a29 (copie a36) et aides de la copie a93 du banc a84, comme le scénario panel d'a177.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
# Avant a185 (PlotService sans AssignOrder) : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A29="$H/../a36-banc/autres-bancs/a29-banc"
O84="$H/../a93-banc/autres-bancs/a84-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-order panel}"
if ! grep -q "AssignOrder" "$SRC/server/Services/PlotService.luau" 2>/dev/null; then
	echo "banc a185 SAUTÉ : cet arbre n'a pas encore l'ordre d'attribution AssignOrder (L-174)"
	echo "banc a185 (ordre des bases, panneau BB_ShopInfo) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES84="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau"

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
		cat "$A29/stubs.luau" "$A29/ext29.luau"
		cat "$A29/../stub-anticheat.luau"
		sources "$FILES84"
		cat "$O84/pre84.luau"
		cat "$A29/setup.luau"
		cat "$O84/lib84.luau"
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
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/; s/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a185 (ordre des bases, panneau BB_ShopInfo) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
