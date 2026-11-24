#!/usr/bin/env bash
# Banc a130 (vague 39, 2026-11-14), partie Fortune Tower : FortuneTowerService.Force et camion bloqué pendant
# une vitrine. Même assemblage que le banc a123 (faux Roblox et mise en place du banc a27 copie a51, register
# d'a123), lus sur place ; scénarios truck (Studio) et prodoff (hors Studio, coupé). « SAUTÉ » sans Force.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-truck prodoff}"
if ! grep -q "function FortuneTowerService.Force" "$SRC/server/Services/FortuneTowerService.luau" 2>/dev/null; then
	echo "banc a130-fortune : SAUTÉ, pas de FortuneTowerService.Force (a130 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
A27="$H/../../../a51-banc/autres-bancs/a27-banc"
A123="$H/../../../a123-banc"
sources() {
	(cd "$SRC" && find "$@" -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
total_checks=0
total_fails=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A27/stubs.luau" "$H/../../../a36-banc/autres-bancs/stub-anticheat.luau"
		sources shared server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/UnboxService.luau server/Services/ContractChecker.luau server/Services/FortuneTowerService.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau client/Controllers/FortuneTowerController.luau
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$A27/setup.luau" "$A123/register.luau" "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
echo "banc a130-fortune : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
