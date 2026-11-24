#!/usr/bin/env bash
# Banc hors Studio d'a290 (21/11, L-270 : le clic part sur toute la taille réelle d'un bouton écrasé par Press = Squash,
# Motion.Activated, Config/UiMotion.ClickZone). Faux Roblox du banc a50 (stubs, ext-motion, ext-a50, setup), ext-a186,
# ext-a189 (tweens simulés), ext-a222 (AnchorPoint), puis ext-a290 (UserInputService avec InputChanged et InputEnded,
# GuiService, InputObject, rendu des tailles absolues d'après le UIScale). Plus une lecture des contrôleurs : plus aucun
# button.Activated:Connect sur un bouton d'écran UI_*. Avant a290 (pas de ClickZone dans Config/UiMotion) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../a50-banc"
X="$H/../a186-banc"
Y="$H/../a189-banc"
Z="$H/../a222-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
if ! grep -q "ClickZone" "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "banc a290 (clic sur la taille réelle du bouton) : SAUTÉ, pas de ClickZone dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
# Contrôleurs encore branchés sur button.Activated (hors outils Tool.Activated, bulles BillboardGui, panneaux
# d'amélioration SurfaceGui et cases de la barre, qui ne passent pas par l'écrasement) : liste écrite pour les tests.
LEFT=$(cd "$SRC/client/Controllers" && for f in *.luau; do grep -E '\.Activated(:Connect|,)' "$f" | grep -qvE '^[[:space:]]*--' && echo "$f"; done | grep -v -E '^(BatController|HitController|BubbleController|UpgradeController|HotbarController)\.luau$' | tr '\n' ' ')
{
	echo "WITH_COSMETIC = true"
	echo "LEFT_ACTIVATED = \"$LEFT\""
	cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a50.luau" "$X/ext-a186.luau" "$Y/ext-a189.luau" "$Z/ext-a222.luau" "$H/ext-a290.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B/setup.luau" "$H/tests.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|vérification\(s\)" ; fi
printf '%s\n' "$out" | grep -qE "^[0-9]+ vérification\(s\), 0 échec\(s\)$"
