#!/usr/bin/env bash
# Banc hors Studio d'a209 (vague 63, L-204 points 1 à 3 : boucle de la caisse exclusive, lueur d'un achat Robux,
# solde de diamants). Faux Roblox du banc a189 lu sur place (a50 : stubs, ext-motion, ext-a50, setup ; a186 ; a189),
# plus ext-a209.luau (AnchorPoint, transparences, UserInputService, GuiService, MarketplaceService).
# Avant la fusion d'a209 (pas de Controllers/UI/CrateLoop) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../a50-banc"
X="$H/../a186-banc"
Y="$H/../a189-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
if [ ! -f "$SRC/client/Controllers/UI/CrateLoop.luau" ]; then
	echo "banc a209 (caisse, lueur d'achat, diamants) : SAUTÉ, pas de Controllers/UI/CrateLoop : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/UiMotionController.luau client/Controllers/ShopFxController.luau server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	echo "WITH_COSMETIC = true"
	cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a50.luau" "$X/ext-a186.luau" "$Y/ext-a189.luau" "$H/ext-a209.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B/setup.luau" "$H/tests.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|vérification\(s\)"; fi
printf '%s\n' "$out" | grep -qE "^[0-9]+ vérification\(s\), 0 échec\(s\)$"
