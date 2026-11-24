#!/usr/bin/env bash
# Banc a196, partie trail : assemblage (appelé par run.sh à travers a190-banc/corrige.sh a155).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A155="$H/../../a178-banc/autres-bancs/a155-banc"
B="$H/../../a62-banc/autres-bancs/a60-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.trail.luau"
{
	awk '{ print } /^	TextScaled = false,$/ { print "	RichText = false, -- a155 : ajout au faux Roblox"; print "	Font = \"Enum.Font.GothamBold\", -- a196 : ajouts au faux Roblox"; print "	TextXAlignment = \"Enum.TextXAlignment.Center\","; print "	TextYAlignment = \"Enum.TextYAlignment.Center\"," }' "$B/stubs.luau"
	cat "$A155/ext-tohex.luau" "$B/ext-motion.luau" "$B/ext-a60.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/../../a134-banc/levier-force.luau" "$H/../../a134-banc/coups-en-rafale.luau"
	cat "$B/setup.luau" "$B/setup-a60.luau"
	cat "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a196 trail : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "banc a196 trail : $line"
printf '%s' "$line" | grep -qE " 0 échec"
