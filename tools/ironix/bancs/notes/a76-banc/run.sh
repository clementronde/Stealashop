#!/usr/bin/env bash
# Banc hors Studio d'a76 (vague 25, 2026-11-11, retour du Play de Cantin) : cases stables de la barre du bas
# UI_Hotbar (HotbarController, Shared/HotbarLayout), glisser-déposer (carte de UI_Inventory → case, case →
# case, case → dehors), disposition gardée dans le profil (HotbarService, remote SetHotbar, attribut
# HotbarLayout), anti double clic de PlaceBox (InventoryController).
# Faux Roblox et mise en place du banc a74 (copie a76 : autres-bancs/a74-banc, elle-même sur le banc a61
# version a62), puis ext76.luau (Vector2, AbsoluteSize, CanvasGroup, UserInputService.InputChanged),
# setup76.luau (vrai HotbarService, layoutBar, mouseDrag, touchDrag) et les scénarios tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a76 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a76}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-stable drag save refused dblclick phone}"
C74="$H/autres-bancs/a74-banc"
A61="$H/../a62-banc/autres-bancs/a61-banc"
B51="$A61/autres-bancs/a51-banc"
B53="$A61/autres-bancs/a53-banc"
if [ ! -f "$SRC/shared/HotbarLayout.luau" ]; then
	echo "banc a76 (cases stables de la barre) : SAUTÉ, pas de Shared/HotbarLayout (a76 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/HotbarService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/HotbarController.luau client/Controllers/Unbox"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$A61/ext61.luau" "$C74/ext74.luau" "$H/ext76.luau"
		sources
		cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A61/setup61.luau" "$C74/setup74.luau" "$H/setup76.luau" "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a76 (cases stables de la barre) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
