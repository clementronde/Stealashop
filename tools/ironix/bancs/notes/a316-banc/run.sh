#!/usr/bin/env bash
# Banc hors Studio d'a316 (2026-11-23, demandes de Clément L-295 et L-296) :
#   best : faux Roblox du banc a29 (copie a36) et aides de la copie a93 du banc a84, comme a185 :
#          L-295, objet exposé posé sur une place montée à y 2,75 (pivot sur la place, rien sous le dessus du socle),
#          fitFactor de DisplayService avec FitSize (6,5 ; 12,5 ; 6) ;
#          L-296, BestIcon de BB_ShopInfo rempli avec ICON_ du meilleur objet, changé avec lui, caché et vide sans icône
#          livrée ou sans objet exposé ; HPIcon jamais rempli.
#   source : contrôles du code (ce que la revue L-295 a constaté) et du contrat (Contract/UI).
# Arbre sans BestIcon (avant a316) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A29="$H/../a36-banc/autres-bancs/a29-banc"
O84="$H/../a93-banc/autres-bancs/a84-banc"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a316 (places à y 2,75, BestIcon)"
if ! grep -q 'BEST_ICON_FIELD = "BestIcon"' "$SRC/client/Controllers/PvPController.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas de BestIcon dans PvPController : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES84="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0

# 1. Scénario « best ».
OUT="$OUTDIR/run.best.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A29/stubs.luau" "$A29/ext29.luau"
	cat "$A29/../stub-anticheat.luau"
	sources "$FILES84"
	cat "$O84/pre84.luau"
	cat "$A29/setup.luau"
	cat "$O84/lib84.luau"
	tr -d '\r' < "$H/tests.best.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "scénario best : arrêté avant la fin (erreur ci-dessus)"
	total_fails=$((total_fails + 1))
else
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/; s/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  best : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
fi

# 2. Contrôles du code source.
sc=0; sf=0
ok() { sc=$((sc + 1)); }
ko() { sc=$((sc + 1)); sf=$((sf + 1)); echo "  ÉCHEC source : $1"; }
src() { tr -d '\r' < "$SRC/$1"; }
has() { src "$1" | grep -qF -- "$2" && ok || ko "$1 sans « $2 »"; }
# L-295 : la hauteur des places est lue dans le modèle, jamais en dur.
has server/Services/DisplayService.luau "local pivot = attachment.WorldCFrame"
has server/Services/DisplayService.luau "fitSizeOf(attachment)"
has client/Controllers/DisplayController.luau "prompt.Parent = attachment"
has server/Services/PvPService.luau "(root.Position - attachment.WorldPosition).Magnitude"
has server/Services/RayonService.luau "for _, descendant in model:GetDescendants() do"
has server/Services/RayonService.luau "model.DescendantAdded:Connect"
for word in "Awnings" "SocleDecor" "13.5" "UnboxBench_0"; do
	if grep -rqF --include="*.luau" -- "$word" "$SRC"; then ko "src/ cite « $word »"; else ok; fi
done
# L-296 : BestIcon branché, contrat.
has client/Controllers/PvPController.luau 'BEST_ICON_FIELD = "BestIcon"'
has client/Controllers/PvPController.luau "Icons.get(itemId)"
has shared/Contract/UI.luau '{ Path = "BestItem.BestIcon", Class = "ImageLabel", Optional = true'
has shared/Contract/UI.luau '{ Path = "BestItem.BestLabel", Class = "TextLabel", Optional = true'
n=$(src shared/Contract/UI.luau | grep -cF 'Name = "BB_ShopInfo"')
if [ "$n" = "1" ]; then ok; else ko "BB_ShopInfo défini $n fois dans Contract/UI"; fi
if src client/Controllers/PvPController.luau | grep -qF '"HPIcon"'; then ko "PvPController touche HPIcon"; else ok; fi
echo "  source : $sc contrôles, $sf raté(s)"
total_checks=$((total_checks + sc))
total_fails=$((total_fails + sf))

echo "$NAME : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
