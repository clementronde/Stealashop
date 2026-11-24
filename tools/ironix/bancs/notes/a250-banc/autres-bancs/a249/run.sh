#!/usr/bin/env bash
# a250 : copie du lanceur du banc a249. Le scénario coince (Ka, Kb) construit son panneau mince sous le nom Shelf_Test249 :
# depuis a250 (Chase.StuckThinPrefix = "Shelf"), seul un bout de rayon est traversable pour la règle « coincé » ; une
# porte ou une vitrine reste un mur (banc a250, scénario porte). Sans a250 (pas de StuckThinPrefix) : le lanceur d avant.
ME="$(cd "$(dirname "$0")" && pwd)"
A249="/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a249-banc"
R="${1:-/f/StealAShop}"
if ! grep -q "StuckThinPrefix" "${R%/src}/src/shared/Config/Chase.luau" 2>/dev/null; then
	exec bash "$A249/run.sh" "$@"
fi
set -u
H="$A249"
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
	bash "$A249/assemble.sh" "$SRC" "$ME/tests.a249.luau" "$name" > "$OUT"
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
