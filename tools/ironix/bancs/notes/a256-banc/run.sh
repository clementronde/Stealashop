#!/usr/bin/env bash
# Banc hors Studio d a256 (vague 73, L-230 : HUD caché à l image où une grande fenêtre s allume, flou 16 sous la caméra, fenêtre 0,84 → 1 ; HudMask.HideScreens).
# Faux Roblox et mise en place du banc a50 lus sur place (stubs.luau, ext-motion.luau, ext-a50.luau, setup.luau),
# ext-a186.luau du banc a186 et ext-a189.luau du banc a189 (tweens simulés dans le temps).
# Avant la fusion d a256 (pas de WindowTas dans Config/UiMotion) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../a50-banc"
X="$H/../a186-banc"
Y="$H/../a189-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
if ! grep -q "WindowTas" "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "banc a256 (fenêtres comme Throw a Seed, vague 73) : SAUTÉ, pas de WindowTas dans $SRC : 0 vérification(s), 0 échec(s)"
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
	cat "$B/setup.luau" "$H/tests.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|vérification\(s\)" ; fi
printf '%s\n' "$out" | grep -qE "^[0-9]+ vérification\(s\), 0 échec\(s\)$"
