#!/usr/bin/env bash
# a172 (2026-11-15, vague 53) : copie de lanceur d'a169-banc/autres-bancs/a107 (tests.a107.luau et ../a28 lus là-bas).
# Features.ShelfOpen est parti : la passe « ancien » (tout le banc a28 avec l'interrupteur à false) refaisait le banc a28,
# qui tourne déjà seul, et n'a plus d'interrupteur à forcer ; seule la passe « nouveau » reste, sources lues telles quelles.
# Arbre avec Features.ShelfOpen : le banc tel quel.
_A172_R="${1:-/f/StealAShop}"
if grep -q "ShelfOpen = true" "$_A172_R/src/shared/Config/Features.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a169-banc/autres-bancs/a107/run.sh" "$@"; fi
set -u
TMP7="$(mktemp -d)"
trap 'rm -rf "$TMP7"' EXIT
H="$(cd "$(dirname "$0")/../../../a169-banc/autres-bancs/a107" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
A28="$H/../a28" # copie a134 : les scénarios d'a28 mis à jour (a134-banc/autres-bancs/a28)
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "SetLuckOverride" "$SRC/server/Services/StoreHeistService.luau" 2>/dev/null; then
	echo "banc a107 (tuto L-112) : SAUTÉ (arbre d'avant a107), 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/TutorialService.luau client/Controllers/TutorialController.luau"
sources() { # $1 = valeur de Features.ShelfOpen
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" -v shelf="$1" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
total_checks=0
total_fails=0
for mode in nouveau; do
	OUT="$TMP7/run.$mode.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A28/stubs.luau" "$A28/ext.luau" "$A28/ext28.luau"
		if [ "$mode" = "ancien" ]; then
			sources false
			cat "$A28/tests.luau"
		else
			sources true
			awk '/^print\("== A\. Config\/Tutorial"\)/ { exit } { print }' "$A28/tests.luau"
			sed 's/check(Features\.ShelfOpen == true, "[^"]*")/check(Features.ShelfOpen == nil, "a172 : Features.ShelfOpen n existe plus")/' "$H/tests.a107.luau" # a172 : l interrupteur est parti
		fi
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "passe $mode : arrêtée avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  passe $mode (ShelfOpen = $([ "$mode" = ancien ] && echo false || echo true)) : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a107 (tuto L-112) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
