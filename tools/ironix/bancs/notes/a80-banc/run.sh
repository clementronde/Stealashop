#!/usr/bin/env bash
# Banc hors Studio d'a80 (vague 26, 2026-11-11, L-097 points 6 et 7) : VfxController.
#   vfx : FX_ChaseHighlight sur le vigile qui poursuit (place gardée chez ShelfBoxController), billets et
#         pièces du ramassage (5 à 12, détruits), FX_Escape aux pieds du joueur via UiFeelController.Escape
#         (Emit(EmitCount), lumière éteinte en FadeTime, détruit après Duration), FX_TruckDust à l'arrivée
#         (SpawnedAt récent) et au départ (LeftAt, pas après l'explosion), BB_Rarest (rareté, couleur, nom,
#         Odds caché, Rays et CrownIcon animés) ; VISUAL EFFECTS OFF.
# Faux Roblox : copie d'a62 du banc a60 + ext-a75.luau + ext-a80.luau ; montage setup, setup-a60, setup-a75.
# « SAUTÉ » sur un arbre sans VfxController.
#   bash run.sh [racine du dépôt]      VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B60="$H/../a62-banc/autres-bancs/a60-banc"
A75="$H/../a75-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/client/Controllers/VfxController.luau" ]; then
	echo "banc a80 (effets de Clément, VfxController) : SAUTÉ, pas de VfxController (a80 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau client/Controllers/NotifyController.luau client/Controllers/VfxController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.vfx.luau"
{
	cat "$B60/stubs.luau" "$B60/ext-motion.luau" "$B60/ext-a60.luau" "$A75/ext-a75.luau" "$H/ext-a80.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B60/setup.luau" "$B60/setup-a60.luau" "$A75/setup-a75.luau" "$H/tests.vfx.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a80 (effets de Clément, VfxController) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
echo "banc a80 (effets de Clément, VfxController) : $line"
case "$line" in *", 0 échec(s)") exit 0;; *) exit 1;; esac
