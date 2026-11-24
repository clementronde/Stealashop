#!/usr/bin/env bash
# Copie a142 (2026-11-14) : une case d objet met l objet en main (HoldItem) ; voir les lignes « a142 » des scénarios.
# Copie d'a76 (2026-11-11, vague 25, cases stables de la barre du bas, Shared/HotbarLayout, HotbarService) :
# cases vides montrées (Slot_Empty_<rang>), plus de décalage, chose nouvelle dans la première case vide ;
# HotbarService monté (setup76.luau, ext76.luau du banc a76) ; tests.slots, tests.use, tests.chase et tests.hud
# adaptés. Sur un arbre sans src/shared/HotbarLayout.luau : relance le banc a74 tel quel.
# Banc hors Studio d'a74 (vague 24, 2026-11-11, L-095 point 6) : la barre du bas UI_Hotbar de Clément,
# HotbarController, en plus de l'écran UI_Inventory. Cases dans l'ordre (outil de casse, batte, colis et
# objets du plus récent au plus ancien), 6 cases sur PC et 4 sur téléphone (attributs SlotCount et
# TouchSlotCount de Bar), touches 1 à 6 (une seule écoute, InventoryController.SetSlotKeys), clic,
# Equipped, Income, son UI_Equip et « <outil> equipped! », poursuite qui garde la barre cachée,
# InventoryButton des deux colonnes du HUD (LeftRail et LeftRailTouch).
# Faux Roblox et mise en place du banc a61, version a62 (../a62-banc/autres-bancs/a61-banc : ses copies
# d'a51 et d'a53, ext61.luau, setup61.luau), lus sur place ; puis setup74.luau (écran UI_Hotbar,
# InventoryButton de LeftRailTouch, bouchons ChaseController, ChaseFeelController et NotifyController,
# vrai HotbarController) et les scénarios tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a74 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a76}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-slots use chase phone hud}"
# a142 (2026-11-14) : arbre sans HeldItemService (avant a142) : la copie a76 de ce banc, telle quelle.
if [ ! -f "$SRC/server/Services/HeldItemService.luau" ]; then
	exec bash "$H/../../../a76-banc/autres-bancs/a74-banc/run.sh" "$ROOT" "$@"
fi
A61="$H/../../../a62-banc/autres-bancs/a61-banc"
A76="$H/../../../a76-banc"
B51="$A61/autres-bancs/a51-banc"
B53="$A61/autres-bancs/a53-banc"
# Arbre d'avant la fusion d'a74 (un autre agent lance run-all-bancs.sh sur son worktree) : rien à
# tester, on le dit et on passe.
if [ ! -f "$SRC/shared/HotbarLayout.luau" ]; then
	exec bash "$H/../../../a74-banc/run.sh" "$ROOT" "$@"
fi
if [ ! -f "$SRC/client/Controllers/HotbarController.luau" ]; then
	echo "banc a74 (barre du bas) : SAUTÉ, pas de HotbarController (a74 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
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
		cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$A61/ext61.luau" "$H/ext74.luau" "$A76/ext76.luau"
		sources
		cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$A61/setup61.luau" "$H/setup74.luau" "$A76/setup76.luau" "$H/tests.$name.luau"
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
echo "banc a74 (barre du bas, copie a142) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
