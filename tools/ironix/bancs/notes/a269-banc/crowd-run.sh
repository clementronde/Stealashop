#!/usr/bin/env bash
# Banc a269, partie foule : vrai WitnessCrowdController sur le faux Roblox du banc a240 crowd (ses lignes avant
# « -- B1. »), puis crowd-tests.luau. Deux parties : « on » (Crowd.Spacing.Enabled = true) et « off » (false).
# « SAUTÉ » sur un arbre sans Crowd.Spacing (avant a269).
#   bash crowd-run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
HARNESS="$H/../a240-banc/crowd/tests.luau"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a269 crowd"
if ! grep -q "Spacing = {" "$SRC/shared/Config/Witness.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas de Crowd.Spacing : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="client/Controllers/WitnessCrowdController.luau shared/WitnessGauge.luau shared/Config/Witness.luau shared/Config/DeepFreeze.luau shared/Contract/Find.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total=0; fails=0
for part in on off; do
	OUT="$TMP/$part.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
		if [ "$part" = "off" ]; then echo "CROWD_OFF = true"; else echo "CROWD_OFF = false"; fi
		echo "SOURCES = {}"
		printf '%s\n' $FILES | awk -v root="$SRC" -v off="$part" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); if (off == "off") sub(/Spacing = \{\n\t\t\tEnabled = true/, "Spacing = {\n\t\t\tEnabled = false", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
		tr -d '\r' < "$HARNESS" | awk '/^-- B1\. /{exit} {print}'
		tr -d '\r' < "$H/crowd-tests.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^$NAME $part : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "$NAME $part : arrêté avant la fin (erreur ci-dessus)"
		fails=$((fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|MESURE|  F" || true; fi
	echo "$line"
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
done
echo "$NAME : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
