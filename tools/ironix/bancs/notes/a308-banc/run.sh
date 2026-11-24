#!/usr/bin/env bash
# Banc hors Studio d'a308 (22/11, Cantin : EquipButton des boutiques d'armes et d'auras sans survol ni clic, car il remplit
# son parent). Faux Roblox du banc a60 (stubs, ext-motion, ext-a60, setup, setup-a60) et le vrai UiFeelController.
# Scénarios :
#   - liste : Config/UiMotion telle quelle (Hover.FillParentScreens = UI_WeaponShop, UI_AuraShop) ;
#   - vide  : FillParentScreens = {} dans la source avant le require (comportement d'avant a308).
# Arbre sans a308 (pas de FillParentScreens dans Config/UiMotion) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$H/.."
B="$N/a60-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
NAME="banc a308 (boutons qui remplissent leur parent, boutiques d'armes et d'auras)"
if ! grep -q "FillParentScreens = " "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas de Hover.FillParentScreens dans $SRC : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total=0; fails=0
for part in liste vide; do
	OUT="$TMP/run.$part.luau"
	{
		cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a60.luau"
		sources
		if [ "$part" = "vide" ]; then
			echo 'EMPTY_LIST = true'
			echo 'SOURCES["shared/Config/UiMotion.luau"] = (string.gsub(SOURCES["shared/Config/UiMotion.luau"], "FillParentScreens = %b{}", "FillParentScreens = {}", 1))'
		fi
		cat "$B/setup.luau" "$B/setup-a60.luau" "$H/tests.luau"
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
