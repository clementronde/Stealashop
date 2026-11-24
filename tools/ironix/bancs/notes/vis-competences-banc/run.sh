#!/usr/bin/env bash
# Banc hors Studio « vis-competences » (2026-11-13, règle de Cantin) : un visuel de la boutique lié à une
# compétence de l'arbre (caméras de Stage_5…) reste caché tant que le propriétaire ne l'a pas débloquée, quel
# que soit le niveau de la boutique, et apparaît dès le déblocage (ShopWallsService, Config/SkillTree.PlotVisuals,
# attribut ShowFromSkill). Harnais : celui de la copie a93 du banc a84 (faux Roblox et mise en place d'a29 lus
# sur place, lib84 et pre84), plus le vrai ShopStageService.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
# Arbre sans PlotVisuals dans Config/SkillTree : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A84="$H/../a93-banc/autres-bancs/a84-banc"
A29="$H/../a36-banc/autres-bancs/a29-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "PlotVisuals" "$SRC/shared/Config/SkillTree.luau" 2>/dev/null; then
	echo "banc vis-competences SAUTÉ : cet arbre n'a pas encore SkillTree.PlotVisuals"
	echo "banc vis-competences (visuels de compétences) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau server/Services/ShopStageService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau"
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
OUT="$OUTDIR/run.visuals.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A29/stubs.luau" "$A29/ext29.luau"
	cat "$A29/../stub-anticheat.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$A84/pre84.luau"
	cat "$A29/setup.luau"
	cat "$A84/lib84.luau"
	cat "$H/tests.visuals.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -15
	echo "banc vis-competences (visuels de compétences) : 0 vérification(s), 1 échec(s) (arrêté avant la fin)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then
	printf '%s\n' "$out"
else
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true
fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc vis-competences (visuels de compétences) : $c vérification(s), $f échec(s)"
exit $((f > 0))
