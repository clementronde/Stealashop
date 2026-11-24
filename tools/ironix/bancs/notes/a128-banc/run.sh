#!/usr/bin/env bash
# Banc hors Studio d'a128 (vague 39, 2026-11-14, optimisation téléphone, corrections 1, 3, 4 et 5 de
# docs/claude/notes/perf-telephone.md et BenchBarController). Un scénario par fonction touchée :
#   idle      ItemIdleController (BulkMoveTo, objets à l'écran, cadence au loin) : faux Roblox de la copie a128
#             d'a22-core (autres-bancs/a22-core : faux Camera FieldOfView / ViewportSize, BulkMoveTo) ;
#   rainbow   CarryController.updateRainbows : collé après les scénarios de la copie a128 d'a17-carry ;
#   countdown HudController (NightCountdown) : collé après les scénarios d'a21-hud (copie a126 si l'arbre
#             n'a plus ReturnBaseButton, copie a62 sinon, comme l'entrée a21-hud du runner) ;
#   bench     BenchBarController : faux Roblox d'a72 (bar/harness.luau).
# MaxOutlines (20) : copies a128 d'a17-shelf et d'a32 (autres-bancs), qui lisent la limite dans Config/ShelfBoxes.
# Copies d'a128 (entrées du runner) : a17-carry, a49 (DescendantAdded dans le faux Roblox), a22-core, a31
# (faux Camera, BulkMoveTo ; a31 : caméra tournée vers les objets), a17-shelf, a32 (limite lue dans Config).
# Sur un arbre sans NearDistance dans Config/ItemIdle (avant la fusion d'a128) : SAUTÉ.
#   bash run.sh [racine du dépôt] [scénarios…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "NearDistance" "$SRC/shared/Config/ItemIdle.luau" 2>/dev/null; then
	echo "banc a128 (optimisation téléphone) : SAUTÉ, pas de NearDistance dans Config/ItemIdle (a128 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-idle rainbow countdown bench}"
sources() {
	(cd "$SRC" && find "$@" -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
OUTDIR="$(mktemp -d)"
[ -n "${KEEP:-}" ] || trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	case "$name" in
	idle)
		{
			cat "$H/autres-bancs/a22-core/stubs.luau" "$H/autres-bancs/a22-core/ext.luau"
			sources shared client/Controllers/ItemIdleController.luau
			cat "$H/tests.idle.luau"
		} > "$OUT" ;;
	rainbow)
		{
			cat "$H/autres-bancs/a17-carry/fake.luau"
			sources shared server/Services client
			awk '/^-+ bilan$/ { exit } { print }' "$H/autres-bancs/a17-carry/tests.luau"
			cat "$H/tests.rainbow.luau"
		} > "$OUT" ;;
	countdown)
		if grep -q '"ReturnBaseButton"' "$SRC/client/Controllers/HudController.luau" 2>/dev/null; then
			HB="$N/a62-banc/autres-bancs/a21-hud"
		else
			HB="$N/a126-banc/autres-bancs/a21-hud"
		fi
		{
			cat "$HB/stubs.luau" "$N/a62-banc/autres-bancs/ext-motion.luau"
			sources shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) client/Controllers/HudController.luau client/Controllers/SkyController.luau
			awk '{ lines[NR] = $0 } END { last = NR; while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--; if (lines[last] ~ /^summary\(\)$/) last--; for (i = 1; i <= last; i++) print lines[i] }' "$HB/tests.luau"
			cat "$H/tests.countdown.luau"
		} > "$OUT" ;;
	bench)
		{
			echo "VERBOSE = false"
			printf 'SOURCE = [==========[\n'
			tr -d '\r' < "$SRC/client/Controllers/BenchBarController.luau"
			printf '\n]==========]\n'
			cat "$N/a72-banc/bar/harness.luau" "$H/tests.bench.luau"
		} > "$OUT" ;;
	*)
		echo "scénario inconnu : $name"
		total_fails=$((total_fails + 1))
		continue ;;
	esac
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario $name : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a128 (optimisation téléphone) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
