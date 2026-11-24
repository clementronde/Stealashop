#!/usr/bin/env bash
# Partie heist du banc a135 : faux Roblox et mise en place du banc a114 (a30 copie a66, head.luau d'a103 copie a114).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
BASE="$H/../a66-banc/autres-bancs/a30-banc"
HEAD="$H/../a114-banc/autres-bancs/a103-banc/head.luau"
if ! grep -q 'police' "$SRC/shared/Net/Definitions.luau" 2>/dev/null; then
	echo "scénario heist : SAUTÉ (pas de chrono de police dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.heist.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$BASE/stubs.luau"
	cat "$BASE/../stub-anticheat.luau"
	sources
	cat "$BASE/setup.luau"
	cat "$HEAD"
	cat "$H/tests.heist.luau"
} > "$OUT"
"$LUAU" "$(cygpath -w "$OUT")" 2>&1 | grep -E "^---|^    |ÉCHEC|ERREUR|error|scénario|^ +ok" | grep -vE "^--- " || true
