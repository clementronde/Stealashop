#!/usr/bin/env bash
# Partie hud du banc a135 : faux Roblox du banc a21-hud (copie a126) et ext-motion.luau (a62), lus sur place.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
D="$H/../a126-banc/autres-bancs/a21-hud"
if ! grep -q 'POLICE IN' "$SRC/client/Controllers/HudController.luau" 2>/dev/null; then
	echo "SAUTÉ (pas de chrono de police dans cet arbre)"
	echo "0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.hud.luau"
FILES="shared client/Controllers/UI client/Controllers/HudController.luau"
{
	cat "$D/stubs.luau"
	cat "$H/../a62-banc/autres-bancs/ext-motion.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/tests.hud.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1
