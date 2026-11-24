#!/usr/bin/env bash
# a426 (24/11, L-319 : vitesse de la zone safe) : harnais du banc a36 (copie d'a146-banc/autres-bancs/a36 : stubs, ext29,
# ext36, setup ; mêmes vrais services) avec les scénarios d'a426 seulement (tests.zone.luau, tests.zoneoff.luau). Lancé
# par ../../run.sh, à travers la même chaîne que le banc a36 du lanceur commun (échelle 1, tapis, correctifs a172 et a158,
# GuardChaseV2 coupé). Chaque scénario tourne dans son propre luau : pre.<nom>.luau s'il existe, setup.luau, tests.
#   bash run.sh <racine du dépôt> [scénarios…]   VERBOSE=1 : lignes ok et sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-${A426_SCENARIOS:-zone zoneoff}}"
FILES="shared server/Services/AntiCheatService.luau server/Services/CarryService.luau server/Services/StatsService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/BatService.luau server/Services/GuardService.luau server/Services/PlotService.luau server/Services/ReturnBaseService.luau server/Services/TrainingService.luau server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/NightCycleService.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext36.luau"
		sources
		if [ -f "$H/../../../a147-banc/retour-base-actif.luau" ]; then cat "$H/../../../a147-banc/retour-base-actif.luau"; fi
		cat "$H/../../../a134-banc/levier-force.luau"
		cat "$H/../../../a134-banc/coups-en-rafale.luau"
		cat "$H/../../../a103-banc/ancien-deroule.luau"
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$H/setup.luau"
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
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a426 (vitesse de la zone safe) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
