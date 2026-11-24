#!/usr/bin/env bash
# Banc hors Studio d'a125 (vague 38, 2026-11-14, liaison L-131 f et g : saut de Glitch porté ou animé, style sur BB_Carry).
# Vrai MutationFxController sur le faux Roblox du banc a104 (copie a116) et les extras du banc a119. Décor (tests.luau)
# copié du banc a119 ; scénarios (tests-a125.luau) : saut de Glitch porté ou animé (copie MutationJump décalée, pièces
# cachées puis remises exactement, jamais déplacées ; suit l objet et l idle ; caché en local suivi ; transparence du
# serveur gardée ; mutation retirée pendant un saut) ; style de mutation sur BB_Carry.Mutation, rien sans elle.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a125"
HARNESS="$H/../a116-banc/autres-bancs/a104-banc/harness.luau"
if ! grep -q "MutationJump" "$SRC/client/Controllers/MutationFxController.luau" 2>/dev/null; then
	echo "$NAME (saut de Glitch porté, BB_Carry) : SAUTÉ, MutationFxController sans saut porté (avant la fusion d a125) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="client/Controllers/MutationFxController.luau"
for m in DeepFreeze MutationFx Mutations; do
	FILES="$FILES shared/Config/$m.luau"
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SHELF_OPEN = true"
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	tr -d '\r' < "$HARNESS"
	tr -d '\r' < "$H/../a119-banc/extras.luau"
	echo "local function __tests()"
	tr -d '\r' < "$H/tests.luau"
	tr -d '\r' < "$H/tests-a125.luau"
	echo "end"
	echo "local ok, err = pcall(__tests)"
	echo "if not ok then print('  ERREUR ' .. tostring(err)); FAILS += 1 end"
	echo "finish('$NAME')"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
out=$("$LUAU" "$W" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME (saut de Glitch porté, BB_Carry) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$NAME (saut de Glitch porté, BB_Carry) : $c vérification(s), $f échec(s)"
exit $((f > 0))
