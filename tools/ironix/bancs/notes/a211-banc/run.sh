#!/usr/bin/env bash
# Banc hors Studio d'a211 (vague 63, bug vu en Play le 16/11) : un joueur attrapé dans un magasin n'en est plus
# l'intrus, aucun 2e vigile de fin de chrono pour lui. Mise en place du banc a202 (a66-banc/autres-bancs/a30-banc,
# a114-banc/autres-bancs/a103-banc/head.luau, a202-banc/pre.luau et head.luau, doublure d'ItemWeight corrigée par
# f56-banc/corrige.sh a202). Vrais : StoreHeistService, GuardService, CarryService, WindowService…
#   caught  C1 attrapé dedans puis fin du chrono : une seule capture, et l'autre intrus (Bob) reste poursuivi
#           C2 intrus sans capture : toujours poursuivi à la fin du chrono
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : lignes ok et sortie
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
if [ -f "$ROOT/src/shared/Config/Weight.luau" ] && [ -z "${A211_CORRIGE:-}" ]; then
	A211_CORRIGE=1 exec bash "$H/../f56-banc/corrige.sh" a202 bash "$0" "$ROOT" "$@"
fi
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a211 (attrapé une fois, pas deux)"
if ! grep -q "SingleBoxReveal" "$SRC/shared/Config/Features.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, a202 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
BASE="$H/../a66-banc/autres-bancs/a30-banc"
HEAD="$H/../a114-banc/autres-bancs/a103-banc/head.luau"
A134="$H/../a134-banc"
A202="$H/../a202-banc"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
SCENARIOS="${*:-caught}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$BASE/stubs.luau"
		cat "$BASE/../stub-anticheat.luau"
		(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
		cat "$A134/levier-force.luau"
		cat "$A134/coups-en-rafale.luau"
		cat "$A202/pre.luau"
		cat "$BASE/setup.luau"
		cat "$HEAD"
		cat "$A202/head.luau"
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
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
