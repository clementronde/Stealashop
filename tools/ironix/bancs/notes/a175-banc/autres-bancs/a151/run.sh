#!/usr/bin/env bash
# Copie a175 (2026-11-15, vague 54, Cantin : le bot ne poursuit qu'à la sortie de sa boutique avec son objet) du banc a151 :
# scénario bot réécrit ici (Bob et Dan prennent un objet, sortent avec, rentrent : le bot les frappe dedans et les éjecte) ;
# owner lu dans a151-banc.
# Arbre sans exitStep dans BotService (avant a175) : relance a151-banc.
if ! grep -q "local function exitStep" "${1:-/f/StealAShop}/src/server/Services/BotService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a151-banc/run.sh" "$@"; fi
# Banc hors Studio d'a151 (vague 43, 2026-11-14, Cantin) : la porte d'une boutique se répare quand l'intrus est éjecté.
# Vrais : PvPService, BatService, BotService, TheftAlertService, StatsService, DisplayService, PlotService, WindowService,
# CarryService, Net, Config, Contract. Faux Roblox et mise en place du banc a32 (copie a37, lus sur place), leviers du
# faux arbre de la copie a134 (levier-force, coups-en-rafale) ; scénario bot : plus ext124.luau du banc a124.
# Scénarios :
#   owner : Ada éjecte Bob alors que Cy est encore dedans : la porte attend ; Cy sort : porte réparée tout de suite
#           (PV max, vol fermé) ; deux intrus éjectés l'un après l'autre : réparée au second ; dernier intrus éjecté :
#           réparée tout de suite ; coup sur un voleur déjà dehors : la porte ne change pas ; porte intacte : rien.
#   bot   : le bot éjecte Bob alors que Cy est dedans : la porte attend, puis se répare quand Cy est sorti ou éjecté.
# La partie témoins et police d'a151 est dans autres-bancs/a100 (copie du banc a100).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
# Avant la fusion d'a151 : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A32="$H/../../../a37-banc/autres-bancs/a32-banc"
A134="$H/../../../a134-banc"
A124="$H/../../../a124-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-owner bot}"
if ! grep -q "repairWhenEmpty" "$SRC/server/Services/PvPService.luau" 2>/dev/null; then
	echo "banc a151 SAUTÉ : cet arbre n'a pas encore la porte réparée à l'éjection"
	echo "banc a151 (porte réparée à l'éjection) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/TheftAlertService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/BotService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/TheftAlertController.luau client/Controllers/BatController.luau client/Controllers/ShelfBoxController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A32/stubs.luau" "$A32/ext29.luau" "$A32/ext32.luau"
		cat "$A32/../stub-anticheat.luau"
		sources
		if grep -q "WalkPerDecade" "$SRC/shared/Config/Balance.luau" 2>/dev/null; then
			cat "$A134/levier-force.luau" "$A134/coups-en-rafale.luau"
		fi
		cat "$A32/setup.luau"
		if [ "$name" = "bot" ]; then cat "$A124/ext124.luau"; fi
		T="$H/tests.$name.luau"; [ -f "$T" ] || T="$H/../../../a151-banc/tests.$name.luau"; cat "$T"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true; fi
	c=$(printf '%s' "$line" | sed -E 's/^(scénario .* : )?([0-9]+) vérification.*/\2/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a151 (porte réparée à l'éjection) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
