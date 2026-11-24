#!/usr/bin/env bash
# Banc hors Studio d'a139 (2026-11-14, optimisation téléphone passe 2, Config/PerfClient). Chaque suite tourne deux
# fois : « on » (Config/PerfClient tel quel) et « off » (ses booléens à false : l'ancien comportement).
#   open : scénarios du banc a104 (copie a116, faux Roblox lu sur place) + tests-open.luau (état des colis lu
#          seulement quand il change ; annulation pendant la sortie ; colis sans tag) ;
#   mut  : scénarios du banc a119 (extras d'a119) puis ceux d'a125, caméra avec champ et écran, + tests-mut.luau
#          après a119 (effet figé hors de l'écran, saut de Glitch fini, objet porté animé, bord de l'écran, objet
#          sans mutation pas relu) ;
#   shelf: scénarios du banc a17-shelf (copie a128, faux Roblox d'a17-banc/carry) + tests-shelf.luau (colis
#          lointains pas relus) ; les lignes TRACE (contours actifs et étiquettes à portée, image par image, sur un
#          trajet de caméra) doivent être identiques entre « on » et « off ».
# « SAUTÉ » sans src/shared/Config/PerfClient.luau.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
# Copie pc-steal (2026-11-14) : faux Roblox de la copie pc-steal du banc a104 (GetPropertyChangedSignal), le reste inchangé.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../../.."
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a139"
PERF="$SRC/shared/Config/PerfClient.luau"
if [ ! -f "$PERF" ]; then
	echo "$NAME (optimisation téléphone, passe 2) : SAUTÉ, pas de Config/PerfClient : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tr -d '\r' < "$PERF" > "$TMP/perf.on.luau"
sed -E 's/= true,/= false,/' "$TMP/perf.on.luau" > "$TMP/perf.off.luau"

# sources <racine> <fichiers…> : blocs SOURCES["…"] = [[…]]
sources() {
	local root="$1"; shift
	printf '%s\n' "$@" | awk -v root="$root" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
perfsource() {
	printf 'SOURCES["shared/Config/PerfClient.luau"] = [==========[\n'
	cat "$TMP/perf.$1.luau"
	printf '\n]==========]\n'
}
run() { # run <fichier> : sortie de luau
	local W="$1"
	if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$1")"; fi
	"$LUAU" "$W" 2>&1
}
total=0; failed=0
tally() { # tally <libellé> <sortie> <motif de la ligne de bilan>
	local label="$1" out="$2" pattern="$3"
	local line
	line=$(printf '%s\n' "$out" | grep -E "$pattern" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | grep -v '^TRACE ' | tail -25
		echo "  $label : arrêté avant la fin"
		failed=$((failed + 1)); return
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out" | grep -v '^TRACE '; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	local c f
	c=$(printf '%s' "$line" | sed -E 's/.*[^0-9]([0-9]+) vérif.*/\1/; s/^([0-9]+) vérif.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $label : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
}

A104="$H/../a104-banc"
OPEN_FILES="client/Controllers/HeistController.luau client/Controllers/ShelfOpenController.luau client/Controllers/ShelfOpen/Logic.luau shared/ShelfOpenState.luau shared/Format.luau shared/Contract/Find.luau"
for m in DeepFreeze ShelfOpen Items Rarities Mutations Balance Features; do OPEN_FILES="$OPEN_FILES shared/Config/$m.luau"; done
MUT_FILES="client/Controllers/MutationFxController.luau shared/Config/DeepFreeze.luau shared/Config/MutationFx.luau shared/Config/Mutations.luau"

for mode in on off; do
	# open
	OUT="$TMP/open.$mode.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
		echo "SHELF_OPEN = true"
		echo "A139_PERF = \"$mode\""
		echo "SOURCES = {}"
		sources "$SRC" $OPEN_FILES
		perfsource "$mode"
		tr -d '\r' < "$A104/harness.luau"
		tr -d '\r' < "$H/pre.luau"
		echo "local function __tests()"
		tr -d '\r' < "$A104/tests.luau"
		tr -d '\r' < "$H/tests-open.luau"
		echo "end"
		echo "local ok, err = pcall(__tests)"
		echo "if not ok then print('  ERREUR ' .. tostring(err)); FAILS += 1 end"
		echo "finish('open $mode')"
	} > "$OUT"
	tally "open $mode" "$(run "$OUT")" "^open $mode : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"

	# mut (a119 + a139, puis a125)
	for suite in a119 a125; do
		OUT="$TMP/mut.$suite.$mode.luau"
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
			echo "SHELF_OPEN = true"
			echo "A139_PERF = \"$mode\""
			echo "A139_CAMERA = true"
			echo "SOURCES = {}"
			sources "$SRC" $MUT_FILES
			perfsource "$mode"
			tr -d '\r' < "$A104/harness.luau"
			tr -d '\r' < "$B/a119-banc/extras.luau"
			tr -d '\r' < "$H/pre.luau"
			echo "local function __tests()"
			if [ "$suite" = "a119" ]; then
				tr -d '\r' < "$B/a119-banc/tests.luau"
				tr -d '\r' < "$H/tests-mut.luau"
			else
				tr -d '\r' < "$B/a125-banc/tests.luau"
				tr -d '\r' < "$B/a125-banc/tests-a125.luau"
			fi
			echo "end"
			echo "local ok, err = pcall(__tests)"
			echo "if not ok then print('  ERREUR ' .. tostring(err)); FAILS += 1 end"
			echo "finish('mut $suite $mode')"
		} > "$OUT"
		tally "mut $suite $mode" "$(run "$OUT")" "^mut $suite $mode : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	done

	# shelf
	OUT="$TMP/shelf.$mode.luau"
	{
		tr -d '\r' < "$B/a17-banc/carry/fake.luau"
		echo "A139_PERF = \"$mode\""
		(cd "$SRC" && find shared client/Controllers/ShelfBoxController.luau -name '*.luau' ! -path 'shared/Config/PerfClient.luau' | sort) | while read -r f; do sources "$SRC" "$f"; done
		perfsource "$mode"
		sed '/^---------------------------------------------------------------- bilan/,$d' "$B/a128-banc/autres-bancs/a17-shelf/tests.luau" | tr -d '\r'
		tr -d '\r' < "$H/tests-shelf.luau"
	} > "$OUT"
	out=$(run "$OUT")
	printf '%s\n' "$out" | grep '^TRACE ' > "$TMP/trace.$mode"
	tally "shelf $mode" "$out" "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
done

# Trajet de caméra : mêmes contours et mêmes étiquettes à portée, image par image, avec et sans le réglage.
lines=$(wc -l < "$TMP/trace.on")
kinds=$(cut -d" " -f3 "$TMP/trace.on" | sort -u | wc -l)
total=$((total + 1))
if [ "$lines" -gt 1000 ] && [ "$kinds" -ge 8 ] && cmp -s "$TMP/trace.on" "$TMP/trace.off"; then
	echo "  shelf trace : $lines images identiques avec et sans ShelfBoxFarSkip ($kinds états différents)"
else
	echo "  ÉCHEC shelf trace : images différentes ou trop peu d états ($lines lignes, $kinds états) :"
	diff "$TMP/trace.on" "$TMP/trace.off" | head -6
	failed=$((failed + 1))
fi
echo "$NAME (optimisation téléphone, passe 2) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
