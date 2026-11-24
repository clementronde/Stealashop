#!/usr/bin/env bash
# Banc hors Studio d'a249 (poursuite phase 2, L-235), vrai GuardService sur le harnais d'a193/a198/a224 :
#   spring / springoff   voleur au-dessus du minimum : retour doux (au plus SpringMaxFactor × sa marche), ni dépassement
#                        ni capture, freinage doux ; « off » = SpringReturn = false (la ruée d'avant, mesures)
#   letsgo               le voleur prend 40 studs d'avance : le vigile revient, au plus SpringMaxFactor × sa marche
#   arret                le voleur au-dessus du minimum s'arrête : attrapé en moins de 5 s (comme avant)
#   below                sous le minimum : toujours attrapé
#   zone1                Zone1SpeedRequired = 10 : Speed 0 attrapé, Speed 10 et plus gardés à distance
#   depart / departoff   départ du vigile StartDelay s après la prise (« off » : 0,5 s)
#   reprise / repriseoff après la cinématique (RevealProtected), il repart StartDelay s plus tard (« off » : tout de suite)
#   double / doubleoff   vigile d'intrus + policier : une seule capture (« off » : OneCatchAtATime et SpringReturn coupés, la double capture se reproduit)
#   coince / coinceoff   a249b : voleur coincé, mur mince entre lui et le vigile : attrapé (« off » : StuckCatch coupé, jamais attrapé)
#   loin / loinoff       a249b : voleur rapide, 150 studs d'avance : jusqu'à SpringFarFactor × la marche de loin (« off » : SpringFar coupé)
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-spring springoff letsgo arret below zone1 depart departoff reprise repriseoff double doubleoff coince coinceoff loin loinoff}"
B="$(cd "$H/.." && pwd)"
if ! grep -q "SpringReturn = true" "$SRC/shared/Config/Chase.luau" 2>/dev/null; then
	echo "banc a249 : SAUTÉ, a249 pas encore fusionné (0 vérification(s), 0 échec(s))"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	bash "$H/assemble.sh" "$SRC" "$H/tests.a249.luau" "$name" > "$OUT"
	pattern="^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	if grep -q "ShelfOpen = true" "$SRC/shared/Config/Features.luau" 2>/dev/null; then
		out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	else
		out=$(bash "$B/a172-banc/corrige.sh" a168 bash -c '"$HOME/.rokit/bin/luau.exe" "$1"' _ "$(cygpath -w "$OUT")" 2>&1)
	fi
	line=$(printf '%s\n' "$out" | grep -E "$pattern" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|échoue|ÉCHOUÉ|^  mesure" || true
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a249 (poursuite phase 2 : retour doux, départ, reprise, une capture, zone 1) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
