#!/usr/bin/env bash
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
D="$H/../a126-banc/autres-bancs/a21-hud"
if ! grep -q 'DevStoreName' "$SRC/server/Services/DataService.luau" 2>/dev/null; then
	echo "SAUTÉ (pas de remise à zéro DEV dans cet arbre)"
	echo "0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.profiles.luau"
FILES="shared server/Services/DataService.luau"
{
	cat "$D/stubs.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$H/tests.profiles.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1
