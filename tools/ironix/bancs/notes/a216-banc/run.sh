#!/usr/bin/env bash
# Banc hors Studio d'a216 (vague 65) : la boutique Robux v2 ne refait plus ses cartes à chaque ouverture
# (RobuxShopController : cartes gardées écran fermé, images des Decal lues en une passe). Faux Roblox et mise en
# place : ceux du banc a208 (a164-banc/autres-bancs/a39-banc : stubs, ext29, ext38, setup ; a208-banc/common.luau),
# lus sur place ; plus le vrai Controllers/UI/Appear (la cascade, lancée comme UiMotionController à l'allumage).
#   open   mesures (copies, passes sur Assets, temps), 2e ouverture sans carte neuve, achat, onglet, fin du pack de
#          départ, cascade à chaque ouverture
# Avant a216 (pas de « decalTextures » dans RobuxShopController) : mesure seule (MESURE=1 force les contrôles).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : toutes les lignes
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A="$H/../a164-banc/autres-bancs/a39-banc"
B="$H/../a208-banc"
ARG="${1:-/f/StealAShop}"
ROOT="${ARG%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "UI_RobuxShop_v2" "$SRC/client/Controllers/RobuxShopController.luau" 2>/dev/null; then
	echo "banc a216 (ouverture de la boutique Robux v2) : SAUTÉ, pas de v2 : 0 vérification(s), 0 échec(s)"
	exit 0
fi
AFTER=false
if grep -q "decalTextures" "$SRC/client/Controllers/RobuxShopController.luau"; then AFTER=true; fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/RobuxShopController.luau client/Controllers/WeaponShopController.luau client/Controllers/AuraShopController.luau client/Controllers/RebirthController.luau client/Controllers/ShopPadController.luau server/Services/ContractChecker.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	echo "A216_AFTER = $AFTER"
	cat "$A/stubs.luau" "$A/ext29.luau" "$A/ext38.luau"
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B/common.luau" "$A/setup.luau" "$H/tests.open.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|MESURE" || true; fi
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a216 (ouverture de la boutique Robux v2) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a216 (ouverture de la boutique Robux v2) : $c vérification(s), $f échec(s)"
exit $((f > 0))
