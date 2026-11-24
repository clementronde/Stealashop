#!/usr/bin/env bash
# Banc hors Studio d'a186 (2026-11-15, vague 58, L-176 : fonds des cartes des boutiques par palier, Shared/ShopCardTier,
# branché par WeaponShopController et AuraShopController). Faux Roblox et mise en place du banc a50 lus sur place
# (stubs.luau, ext-motion.luau, ext-a50.luau, setup.luau), plus ext-a186.luau (Color3.Lerp, Vector2, UIGradient,
# propriétés d'UI). Avant la fusion d'a186 (pas de Shared/ShopCardTier) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../a50-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
if [ ! -f "$SRC/shared/ShopCardTier.luau" ]; then
	echo "banc a186 (fonds des cartes par palier) : SAUTÉ, pas de Shared/ShopCardTier dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau client/Controllers/AuraShopController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	echo "WITH_COSMETIC = true"
	cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a50.luau" "$H/ext-a186.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B/setup.luau" "$H/tests.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|vérification\(s\)" ; fi
printf '%s\n' "$out" | grep -qE "^[0-9]+ vérification\(s\), 0 échec\(s\)$"
