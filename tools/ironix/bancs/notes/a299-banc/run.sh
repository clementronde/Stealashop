#!/usr/bin/env bash
# Banc hors Studio d'a299 (21/11, Cantin : objets de la caisse exclusive fixes ; survol qui grossit autour du centre).
#   - caisse : faux Roblox du banc a209 (a50, a186, a189, ext-a209) et la tête de a209-banc/tests.luau (modules montés,
#     aides, buildShop ; ses vérifications S1 à S11 laissées de côté), puis tests.caisse.luau ;
#   - caisse-bob0 : la même, Config/ShopFx.Crate.Bob mis à 0 dans la source avant le require (Icon figée aussi) ;
#   - survol : faux Roblox du banc a290 (a50, a186, a189, a222, ext-a290), puis tests.survol.luau.
# Arbre sans a299 (pas de Hover.Centered dans Config/UiMotion) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$H/.."
B="$N/a50-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
NAME="banc a299 (caisse fixe, survol centré)"
if ! grep -q "Centered = " "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas de Hover.Centered dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/UiMotionController.luau client/Controllers/ShopFxController.luau server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total=0; fails=0
for part in caisse caisse-bob0 survol; do
	OUT="$TMP/run.$part.luau"
	{
		echo "WITH_COSMETIC = true"
		if [ "$part" = "survol" ]; then
			cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a50.luau" "$N/a186-banc/ext-a186.luau" "$N/a189-banc/ext-a189.luau" "$N/a222-banc/ext-a222.luau" "$N/a290-banc/ext-a290.luau"
			sources
			cat "$B/setup.luau" "$H/tests.survol.luau"
		else
			cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a50.luau" "$N/a186-banc/ext-a186.luau" "$N/a189-banc/ext-a189.luau" "$N/a209-banc/ext-a209.luau"
			sources
			if [ "$part" = "caisse-bob0" ]; then
				echo 'BOB0 = true'
				echo 'SOURCES["shared/Config/ShopFx.luau"] = (string.gsub(SOURCES["shared/Config/ShopFx.luau"], "\tBob = 7,", "\tBob = 0,", 1))'
			fi
			cat "$B/setup.luau"
			sed -n '1,51p;72,119p' "$N/a209-banc/tests.luau"
			cat "$H/tests.caisse.luau"
		fi
	} > "$OUT"
	out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "$NAME $part : arrêté avant la fin (erreur ci-dessus)"
		fails=$((fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	echo "$part : $line"
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c)); fails=$((fails + f))
done
echo "$NAME : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
