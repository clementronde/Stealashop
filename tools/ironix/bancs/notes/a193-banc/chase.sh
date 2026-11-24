#!/usr/bin/env bash
# a193 (2026-11-15, vague 60) : partie poursuite du banc a193, sur le harnais de a174-banc/autres-bancs/a173/chase.sh
# (mêmes morceaux, lus sur place) ; pre.luau et tests.luau à moi. Scénarios : hold catch collide off (voir run.sh).
#   bash chase.sh <racine du dépôt> [scénarios…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A168="$H/../a168-banc"
B146="$H/../a146-banc"
A173="$H/../a174-banc/autres-bancs/a173"
X="$B146/autres-bancs/a36"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-hold catch collide off}"
FILES="shared server/Services/AntiCheatService.luau server/Services/CarryService.luau server/Services/StatsService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/BatService.luau server/Services/GuardService.luau server/Services/PlotService.luau server/Services/ReturnBaseService.luau server/Services/TrainingService.luau server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/NightCycleService.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
sources > "$OUTDIR/sources.luau"
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$X/stubs.luau" "$B146/overlap-ajout.luau" "$X/ext29.luau" "$X/ext36.luau"
		cat "$OUTDIR/sources.luau"
		cat "$H/../a134-banc/levier-force.luau"
		cat "$H/../a134-banc/coups-en-rafale.luau"
		cat "$H/../a103-banc/ancien-deroule.luau"
		echo "A193_SCENARIO = \"$name\""
		cat "$H/pre.luau"
		cat "$X/setup.luau"
		cat "$A168/commun.luau"
		cat "$A173/commun173.luau"
		cat "$H/tests.luau"
	} > "$OUT"
	("$LUAU" "$(cygpath -w "$OUT")" > "$OUTDIR/out.$name.txt" 2>&1) &
done
wait
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	out=$(cat "$OUTDIR/out.$name.txt")
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
echo "poursuite : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
