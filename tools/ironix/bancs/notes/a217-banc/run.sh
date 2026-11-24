#!/usr/bin/env bash
# Banc hors Studio d'a217 (vague 65) : la boutique d'auras ne relit plus tout ReplicatedStorage/Assets ni ne refait ses
# lignes à chaque ouverture (AuraShopController : textures lues en une passe, lignes gardées écran fermé). Faux Roblox
# et mise en place du banc a50 (stubs, ext-motion, ext-a50, setup) et ext-a186 (fonds des cartes), lus sur place ;
# décor des paliers et textures FX_ comme le banc a186.
#   open   mesures (lignes copiées, instances d'Assets parcourues, temps), 2e ouverture sans ligne neuve ni passe sur
#          Assets, achat, équipement, onglet, icônes et effets posés, cascade (StaggerScale) à chaque ouverture
# Avant a217 (pas de « assetTextures » dans AuraShopController) : mesure seule (MESURE=1 force les contrôles).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : toutes les lignes
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../a50-banc"
C="$H/../a186-banc"
ARG="${1:-/f/StealAShop}"
ROOT="${ARG%/src}"
SRC="$ROOT/src"
if [ ! -f "$SRC/shared/ShopCardTier.luau" ]; then
	echo "banc a217 (ouverture de la boutique d'auras) : SAUTÉ, pas de Shared/ShopCardTier : 0 vérification(s), 0 échec(s)"
	exit 0
fi
AFTER=false
if grep -q "assetTextures" "$SRC/client/Controllers/AuraShopController.luau"; then AFTER=true; fi
FILES="shared client/Controllers/UI server/Services/DataService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/WeaponShopController.luau client/Controllers/UpgradeController.luau client/Controllers/AuraShopController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	echo "WITH_COSMETIC = true"
	echo "A217_AFTER = $AFTER"
	if [ "${MESURE:-}" = "1" ]; then echo "MESURE = true"; fi
	cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a50.luau" "$C/ext-a186.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B/setup.luau" "$H/tests.open.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|MESURE" || true; fi
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a217 (ouverture de la boutique d'auras) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a217 (ouverture de la boutique d'auras) : $c vérification(s), $f échec(s)"
exit $((f > 0))
