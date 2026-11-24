#!/usr/bin/env bash
# Banc a196, partie socle (vague 60, T-096) : « BEST ITEM ». Harnais du banc a161 (faux Roblox d'a62 du banc a60 + ext-a75 +
# ext-a80 + ext-a161, mise en place d'a80 lignes 1 à 101, lus sur place), vrai VfxController ; tests.luau d'ici.
# « SAUTÉ » sur un arbre sans Vfx.Rarest.Pick (avant a196).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A161="$H/../../a161-banc"
B60="$A161/../a62-banc/autres-bancs/a60-banc"
A75="$A161/../a75-banc"
A80="$A161/../a80-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q 'Pick = "' "$SRC/shared/Config/Vfx.luau" 2>/dev/null; then
	echo "banc a196 socle : SAUTÉ, pas de Vfx.Rarest.Pick : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau client/Controllers/NotifyController.luau client/Controllers/VfxController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	cat "$B60/stubs.luau" "$B60/ext-motion.luau" "$B60/ext-a60.luau" "$A75/ext-a75.luau" "$A80/ext-a80.luau" "$A161/ext-a161.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B60/setup.luau" "$B60/setup-a60.luau" "$A75/setup-a75.luau"
	sed -n '1,101p' "$A80/tests.vfx.luau"
	cat "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a196 socle : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "banc a196 socle : $line"
printf '%s' "$line" | grep -qE " 0 échec"
