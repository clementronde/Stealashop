#!/usr/bin/env bash
# Banc a196, partie client (vague 60, T-087) : Photo.Bursts émissions par flash dans WitnessController. Faux Roblox et
# monde du banc a182 client (a182-banc/client/tests.luau jusqu'avant « local w1 = newWitness », lu sur place) ; tests.luau d'ici.
# « SAUTÉ » sur un arbre sans Witness.Photo.Bursts (avant a196).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A182="$H/../../a182-banc/client"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a196 client"
if ! grep -q "Bursts = " "$SRC/shared/Config/Witness.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas de Witness.Photo.Bursts : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="client/Controllers/WitnessController.luau shared/WitnessGauge.luau shared/Config/Witness.luau shared/Config/DeepFreeze.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	tr -d '\r' < "$A182/tests.luau" | sed '/^local w1 = newWitness/,$d'
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec"
