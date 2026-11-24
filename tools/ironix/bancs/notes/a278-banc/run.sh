#!/usr/bin/env bash
# Banc hors Studio d'a278 (23/11, L-272) : Hover = "Grow" sur une carte (Motion.HoverCard, Config/UiMotion.HoverGrow) et
# IconHover = "Spring" (UiAttrFx.Spring : pointeur suivi par un ressort, poids d'entrée et de retour).
# Faux Roblox du scénario « survol » d'a299 (a50, a186, a189, a222, ext-a290), puis tests.luau. Fichier assemblé dans
# mktemp -d. Arbre sans a278 (pas de HoverGrow dans Config/UiMotion) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$H/.."
B="$N/a50-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
NAME="banc a278 (Hover Grow, IconHover Spring)"
if ! grep -q "HoverGrow = {" "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas de HoverGrow dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/UiMotionController.luau client/Controllers/ShopFxController.luau client/Controllers/UiFeelController.luau client/Controllers/RobuxShopController.luau server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.a278.luau"
{
	echo "WITH_COSMETIC = true"
	cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a50.luau" "$N/a186-banc/ext-a186.luau" "$N/a189-banc/ext-a189.luau" "$N/a222-banc/ext-a222.luau" "$N/a290-banc/ext-a290.luau"
	sources
	cat "$B/setup.luau" "$H/tests.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$NAME : $c vérification(s), $f échec(s)"
exit $((f > 0))
