#!/usr/bin/env bash
# Banc hors Studio d'a119 (vague 34, 2026-11-13, liaison L-127 point 5 : design des mutations).
# Vrai MutationFxController et Config (MutationFx, Mutations, DeepFreeze) sur le faux Roblox autonome du banc a104
# (copie a116, lu sur place : autres-bancs/a104-banc/harness.luau du banc a116), complété par extras.luau (Random,
# Vector2, NumberRange, HSV, CFrame:VectorToWorldSpace / == / +, Workspace:BulkMoveTo, CollectionService:GetTags).
# Scénarios (tests.luau) : StyleId ; MutationTag (TagGradient à la place de l'UIGradient, LabelColor, StrokeColor,
# remis comme avant) ; ligne Mutation de BB_Item (TextGradient, texte blanc) ; mouvements Shine, Pulse, Glitch, Scan,
# Spin, écran éteint = rien ; objets : Keep, Shade, Saturate, matière, reflet, particules mises à l'échelle, halo et
# Root intacts, doubles Ghost_NN / Glow_NN (copies sans tags ni attributs ni billboard), lumière, arc-en-ciel,
# Pulse, Rainbow, saut de Glitch remis exactement, objet porté suivi, objet loin non animé, échelle stable avant
# l'habillage, mutation retirée et objet détruit = tout nettoyé, FX manquant = objet normal et un avertissement.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a225"
HARNESS="$H/../a116-banc/autres-bancs/a104-banc/harness.luau"
if [ ! -f "$SRC/client/Controllers/MutationFxController.luau" ]; then
	echo "$NAME (mutation de la cinématique) : SAUTÉ, pas de MutationFxController : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="client/Controllers/MutationFxController.luau"
for m in DeepFreeze MutationFx Mutations; do
	FILES="$FILES shared/Config/$m.luau"
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SHELF_OPEN = true"
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	tr -d '\r' < "$HARNESS"
	tr -d '\r' < "$H/../a119-banc/extras.luau"
	echo "local function __tests()"
	tr -d '\r' < "$H/tests.luau"
	echo "end"
	echo "local ok, err = pcall(__tests)"
	echo "if not ok then print('  ERREUR ' .. tostring(err)); FAILS += 1 end"
	echo "finish('$NAME')"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
out=$("$LUAU" "$W" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME (mutation de la cinématique) : arrêté avant la fin : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$NAME (mutation de la cinématique) : $c vérification(s), $f échec(s)"
exit $((f > 0))
