#!/usr/bin/env bash
# f70c1, partie « motion » (correctif f70, B2 et B5) : harnais du banc a256 (faux Roblox et mise en place du banc a50,
# ext-a186 et ext-a189 : tweens simulés), scénario tests.motion.luau. Arbre sans HudHide.Keep (avant f70c1) : « SAUTÉ ».
#   bash motion.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../a50-banc"
X="$H/../a186-banc"
Y="$H/../a189-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
if ! grep -q "Keep = { UI_Displayed" "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "f70c1 motion : SAUTÉ, pas de HudHide.Keep dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/UiMotionController.luau server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	echo "WITH_COSMETIC = true"
	cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a50.luau" "$X/ext-a186.luau" "$Y/ext-a189.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B/setup.luau" "$H/tests.motion.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|vérification\(s\)" ; fi
printf '%s\n' "$out" | grep -qE "^[0-9]+ vérification\(s\), 0 échec\(s\)$"
