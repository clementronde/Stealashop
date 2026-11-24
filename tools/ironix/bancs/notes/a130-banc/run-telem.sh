#!/usr/bin/env bash
# Banc a130 (vague 39, 2026-11-14), partie télémétrie : BatBoxKnockdown, Source Store / Truck / Fortune. Faux Roblox,
# fichiers et mise en place de la copie a126 du banc a35, lus sur place. « SAUTÉ » sans le préfixe Truck_Fortune_.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "FORTUNE_PREFIX" "$SRC/server/Services/TelemetryService.luau" 2>/dev/null; then
	echo "banc a130-telem : SAUTÉ, pas de catégorie Fortune (a130 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
D="$H/../a126-banc/autres-bancs/a35-banc"
FILES="shared server/Services/TelemetryService.luau server/Services/ShopService.luau server/Services/TutorialService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.telem.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$D/stubs.luau" "$D/ext29.luau" "$D/ext32.luau" "$D/ext35.luau"
	cat "$H/../a59-banc/autres-bancs/stub-anticheat.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$D/setup.luau" "$H/tests.telem.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a130-telem : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a130-telem : $c vérification(s), $f échec(s)"
exit $((f > 0))
