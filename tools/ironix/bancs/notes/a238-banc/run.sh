#!/usr/bin/env bash
# Banc hors Studio d'a238 (vague 71, L-213 points 1a à 1d et 8) :
#   v2    (vitrine) List.CanvasSize = Content + UIPadding (AutomaticCanvasSize = None), refait quand Content change ;
#         Clip.Watermark = image de l'Icon ; zZz « Sleeping Guards 60s » ; Ouvrir maintenant « Soon » sans palier créé ;
#   live  (pre.live d'a208, paliers 8101 à 8104) Ouvrir maintenant : bouton et premier palier sans objet, « No item » /
#         « Almost ready » au clic, vraie fenêtre avec un palier ;
#   glow  PurchaseGlow : PhoneThickness sur téléphone (UIStroke, sinon RainbowBorder), remis à la fin, Transparency effacée.
# Faux Roblox : a208 (a164-banc/autres-bancs/a39-banc, a208-banc/common.luau) + prep.luau ; a209 (a50, a186, a189, a209).
# Arbre sans a238 (pas de « NoItemPrice » dans RobuxShopController) : SAUTÉ.
#   bash run.sh [racine du dépôt]   VERBOSE=1 : toutes les lignes
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$(cd "$H/.." && pwd)"
A="$B/a164-banc/autres-bancs/a39-banc"
C="$B/a208-banc"
ARG="${1:-/f/StealAShop}"
ROOT="${ARG%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "NoItemPrice" "$SRC/client/Controllers/RobuxShopController.luau" 2>/dev/null; then
	echo "banc a238 (boutique Robux, lueur d'achat) : SAUTÉ, a238 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SHOP_FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/RobuxShopController.luau client/Controllers/WeaponShopController.luau client/Controllers/AuraShopController.luau client/Controllers/RebirthController.luau client/Controllers/ShopPadController.luau server/Services/ContractChecker.luau"
GLOW_FILES="shared client/Controllers/UI client/Controllers/UiMotionController.luau client/Controllers/ShopFxController.luau server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in v2 live glow; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		if [ "$name" = "glow" ]; then
			echo "WITH_COSMETIC = true"
			cat "$B/a50-banc/stubs.luau" "$B/a50-banc/ext-motion.luau" "$B/a50-banc/ext-a50.luau" "$B/a186-banc/ext-a186.luau" "$B/a189-banc/ext-a189.luau" "$B/a209-banc/ext-a209.luau"
			sources "$GLOW_FILES"
			cat "$B/a50-banc/setup.luau" "$H/tests.glow.luau"
		else
			cat "$A/stubs.luau" "$A/ext29.luau" "$A/ext38.luau"
			sources "$SHOP_FILES"
			cat "$C/common.luau"
			if [ "$name" = "live" ]; then cat "$C/pre.live.luau"; fi
			cat "$A/setup.luau" "$H/prep.luau" "$H/tests.$name.luau"
		fi
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "scénario $name : $c vérification(s), $f échec(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a238 (boutique Robux, lueur d'achat) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
