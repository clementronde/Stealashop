#!/usr/bin/env bash
# Banc hors Studio d'a230 (vague 70, L-189 points 2, 6 et 8, BB_HeldIncome) :
#   bonus  BottomRow : FriendBoost « +X% » (FriendBonus), VipBoost (PassVIP), CashBoost « x2 »/« x4 » et Timer (PassDoubleCash,
#          CashBoostEndsAt), TrainingBoost (PassDoubleTraining) ; ancien HUD sans BottomRow ;
#   night  NightCountdown : PhonePosition et PhoneAnchorPoint sur téléphone seulement, attributs absents ou faux ;
#   held   BB_HeldIncome au-dessus de l'objet en main (copie de Clément ou repli), hauteur sans halo, revenu réécrit,
#          retiré avec le Tool ; Contract/UI (Twins sans InventoryButton, nouveaux noms facultatifs).
# Faux Roblox d a190 (a60, setup190) + setup230.luau (CFrame.RightVector et UpVector, UserInputService pilotable).
#   bash run.sh [racine du dépôt]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
B="$(cd "$H/.." && pwd)"
A60="$B/a134-banc/autres-bancs/a60"
A190="$B/a205-banc/autres-bancs/a190"
if [ ! -f "$SRC/client/Controllers/HeldIncomeController.luau" ]; then
	echo "banc a230 (BottomRow, nuit sur téléphone, BB_HeldIncome) : SAUTÉ, a230 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/HudMenuController.luau client/Controllers/HeldIncomeController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.a230.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A60/stubs.luau"
	sed -E -f "$A190/patches/quint.sed" "$A60/ext-motion.luau"
	cat "$A60/ext-a60.luau" "$B/a155-banc/ext-tohex.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$A60/setup.luau" "$A60/setup-a60.luau" "$A190/setup190.luau" "$H/setup230.luau" "$H/tests.a230.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a230 (BottomRow, nuit sur téléphone, BB_HeldIncome) : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|échoue|ÉCHOUÉ" || true; fi
c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
echo "banc a230 (BottomRow, nuit sur téléphone, BB_HeldIncome) : $c vérification(s), $f échec(s)"
exit $((f > 0))
