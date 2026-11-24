#!/usr/bin/env bash
# a247 : assemble le scénario serverluck sur la mise en place du banc a38 (voir run.sh).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../a134-banc/autres-bancs/a38"
ROOT="$1"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
FILES="shared server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/RobuxShopController.luau client/Controllers/UI/Motion.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.serverluck.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$B/stubs.luau" "$B/ext29.luau" "$B/ext38.luau" "$B/stub-anticheat.luau" "$H/../a53-banc/ext51.luau"
	sources
	# StoreHeistService en texte seulement (lu par le scénario, jamais requis ici).
	awk -v p="$SRC/server/Services/StoreHeistService.luau" 'BEGIN { RS = "^$"; getline c < p; gsub(/\r/, "", c); printf "HEIST_SOURCE = [==========[\n%s\n]==========]\n", c }'
	cat "$H/../a134-banc/levier-force.luau" "$H/../a134-banc/coups-en-rafale.luau"
	cat "$B/pre.on.luau" "$B/setup.luau" "$H/../a53-banc/autres-bancs/compat51.luau"
	cat "$H/tests.serverluck.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a247 (chance du serveur) : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a247 (chance du serveur) : $c vérification(s), $f échec(s)"
exit $((f > 0))
