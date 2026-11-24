#!/usr/bin/env bash
# a241 (vague 72, L-219 point 2) : copie du lanceur a134-banc/autres-bancs/a110/run.sh (scénario « exit » seul),
# chemins fixés sur a134-banc/autres-bancs/a110 (head103, levier-force, coups-en-rafale) et a66-banc (stubs, setup),
# tests d'a241 (Config/Chase.ChaseOnEmptyExit = true : sorti sans objet avant la fin du chrono, un vigile sort).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
S="$(cd "$H/../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
BASE="$S/a66-banc/autres-bancs/a30-banc"
A110="$S/a134-banc/autres-bancs/a110"
LABEL="banc a241 (sortir sans rien après la casse : le vigile sort)"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.exit.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$BASE/stubs.luau"
	cat "$BASE/../stub-anticheat.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$S/a134-banc/levier-force.luau"
	cat "$S/a134-banc/coups-en-rafale.luau"
	cat "$BASE/setup.luau"
	cat "$A110/head103.luau"
	cat "$H/tests.exit.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$LABEL : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$LABEL : $c vérification(s), $f échec(s)"
exit $((f > 0))
