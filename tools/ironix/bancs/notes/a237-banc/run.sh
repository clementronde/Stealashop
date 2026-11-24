#!/usr/bin/env bash
# Banc hors Studio d'a237 (vague 71, L-221) : AmbienceController, sons d'ambiance PlayAt = Day / Night, fondu au
# changement de phase (NightPhase du Workspace), sons arrivés plus tard, sons sans PlayAt intouchés.
# Faux Roblox minimal dans tests.a237.luau ; vrais : AmbienceController, Contract/Attributes, Night.AmbienceFade.
# « SAUTÉ » sans AmbienceController (a237 pas encore fusionné).
#   bash run.sh [racine du dépôt]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a237 (sons d'ambiance jour et nuit)"
if [ ! -f "$SRC/client/Controllers/AmbienceController.luau" ]; then
	echo "$NAME : SAUTÉ, pas d'AmbienceController (a237 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FADE=$(tr -d '\r' < "$SRC/shared/Config/Night.luau" | grep -oE "AmbienceFade = [0-9.]+" | grep -oE "[0-9.]+$")
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.a237.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	echo "SOURCES = {}"
	echo "NIGHT_FADE = ${FADE:-nil}"
	(cd "$SRC" && printf '%s\n' shared/Contract/Attributes.luau client/Controllers/AmbienceController.luau) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	tr -d '\r' < "$H/tests.a237.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|échoue|ÉCHOUÉ" || true; fi
c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
echo "$NAME : $c vérification(s), $f échec(s)"
exit $((f > 0))
