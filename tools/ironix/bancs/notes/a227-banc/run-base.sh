#!/usr/bin/env bash
# Banc a227 (vague 69, L-175 : UI_TheftAlert n'est plus qu'un bandeau ; ThiefName, ItemName, Arrow facultatifs) :
# le vrai ContractChecker sur le faux Roblox du banc a40 (a117-banc/autres-bancs/a40-banc, lu sur place), scénario tests.a227.luau.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A40="$H/../a117-banc/autres-bancs/a40-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau server/Services/ContractChecker.luau client/Controllers/IndexController.luau client/Controllers/UI/Motion.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
OUT="$OUTDIR/run.a227.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A40/stubs.luau" "$A40/ext29.luau" "$A40/ext38.luau" "$A40/stub-anticheat.luau" "$A40/../../../a53-banc/ext51.luau"
	sources
	cat "$A40/features.luau" "$A40/pre.on.luau"
	cat "$A40/setup.luau" "$A40/../../../a53-banc/autres-bancs/compat51.luau"
	cat "$H/tests.a227.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a227 (alerte de vol en bandeau) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a227 (alerte de vol en bandeau) : $c vérification(s), $f échec(s)"
exit $((f > 0))
