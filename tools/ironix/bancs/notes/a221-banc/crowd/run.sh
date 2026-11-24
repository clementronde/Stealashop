#!/usr/bin/env bash
# Banc a221, partie crowd (vague 66, L-210 point 4) : la foule qui filme le voleur à sa sortie du magasin
# (WitnessCrowdController), sur un faux Roblox à lui (tests.luau ; WitnessController, Features et Settings en bouchons).
# « SAUTÉ » sur un arbre sans WitnessCrowdController (avant a221).
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a221 crowd"
if [ ! -f "$SRC/client/Controllers/WitnessCrowdController.luau" ]; then
	echo "$NAME : SAUTÉ, pas de WitnessCrowdController : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="client/Controllers/WitnessCrowdController.luau shared/WitnessGauge.luau shared/Config/Witness.luau shared/Config/DeepFreeze.luau shared/Contract/Find.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
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
