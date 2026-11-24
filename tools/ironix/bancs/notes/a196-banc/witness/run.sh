#!/usr/bin/env bash
# Banc a196, partie witness (vague 60, T-087) : le témoin loin presse le pas pour être à son poste avant l'appel. Vrai
# WitnessService ; harnais et liste des sources du banc a182 (harnais a100 copie a151, lu sur place).
# « SAUTÉ » sur un arbre sans Witness.Photo.ApproachLead (avant a196).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A100="$H/../../a151-banc/autres-bancs/a100/witness"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a196 witness"
if ! grep -q "ApproachLead" "$SRC/shared/Config/Witness.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas de Witness.Photo.ApproachLead : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="server/Services/WitnessService.luau shared/WitnessGauge.luau"
for m in Balance Cosmetics DeepFreeze Features Items Rarities Tools Witness Zones; do # a210 (vague 63) : Features ajouté (Config/Cosmetics le requiert)
	FILES="$FILES shared/Config/$m.luau"
done
for m in Animations Find Models UI; do
	FILES="$FILES shared/Contract/$m.luau"
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	tr -d '\r' < "$A100/harness.luau"
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
