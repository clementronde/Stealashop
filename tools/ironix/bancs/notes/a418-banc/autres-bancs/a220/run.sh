#!/usr/bin/env bash
# a418 (23/11, variante A2) : copie du banc a220 (N et A204 ramenés au dossier partagé) ; tests.shelf.luau : objet ×2,5 au lieu de ×2 (Reveal.Shelf.MinScale 2,1).
# Banc hors Studio d'a220 (vague 66, L-210 point 3) : le meuble casse sous un objet plus gros que lui pendant la
# cinématique d'ouverture (Controllers/Reveal/Shelf, Config/Reveal.Shelf), sur la mise en place du banc a204
# (autres-bancs/a204, Reveal/Shelf monté).
#   shelf  pièces touchées, exclusions, morceaux, son, remise, ×5, ×1, appareil faible
# Arbre sans a220 (pas de Reveal/Shelf) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)" # a418 : copie dans a418-banc/autres-bancs/a220
A204="$N/a220-banc/autres-bancs/a204" # a418 : la mise en place du banc a220 d origine
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a220 (meuble qui casse)"
if [ ! -f "$SRC/client/Controllers/Reveal/Shelf.luau" ]; then
	echo "$LABEL : SAUTÉ, a220 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-shelf}"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
A68="$N/a71-banc/autres-bancs/a68-banc"
FILES="shared client/Controllers/UI client/Controllers/Reveal client/Controllers/RevealController.luau"
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	case "$name" in
	shelf) TESTS="$H/tests.shelf.luau" ;;
	*)
		echo "scénario inconnu : $name"
		total_fails=$((total_fails + 1))
		continue
		;;
	esac
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A68/stubs.luau"
		sources "$FILES"
		cat "$A204/pre.client.luau"
		cat "$N/a71-banc/autres-bancs/a42-banc/setup.luau"
		cat "$A68/common.luau"
		cat "$A204/head.client.luau"
		cat "$TESTS"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
