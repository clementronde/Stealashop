#!/usr/bin/env bash
# Copie d'a62 (2026-11-11, vague 22, L-092 3g) : ext61.luau ajoute les signaux InputBegan et InputEnded
# (Motion.Button suit la fin du toucher). Tests inchangés ; autres-bancs copiés tels quels.
# Banc hors Studio d'a61 (vague 21, 2026-11-10, L-079, L-089, L-091 point 6) : l'écran UI_Inventory de
# Clément remplace toute la barre d'outils de Roblox. InventoryService écrit l'état de l'inventaire dans
# l'attribut InventoryState du Player (plus de Tool de colis ni d'objet), remotes PlaceItemAuto(itemUid) et
# UnplaceItem(itemUid) ; InventoryController : bouton InventoryButton, onglets, cartes de chaque section
# (objets, colis, outils, potions vides), ScrollTrack, compteurs, Equip Best, pose d'un objet et d'un colis
# depuis l'écran (mode pose sans Tool), outil et batte mis en main depuis l'écran et par les touches 1 et 2,
# barre Roblox coupée ; remotes refusés.
# Faux Roblox de la copie d'a61 d'a51 (autres-bancs/a51-banc : stubs.luau d'a36, ext29, ext38, ext46, ext51
# avec SetCoreGuiEnabled et TouchTap), ext53 de la copie d'a53 (ScrollingFrame, UIListLayout, InputBegan),
# complété par ext61.luau (MouseEnter, MouseLeave, UIGridLayout) ; mise en place setup.luau de la copie
# d'a51, puis setup61.luau (écrans du relevé de Studio, icônes d'outils).
# Vrais : InventoryService, DataService (faux ProfileStore d'ext38), DisplayService, PlotService,
# UnboxService, MonetizationService, IndexService, TrainingService, StatsService, ToolService, ShopService,
# InventoryController, UnboxController, UI/Motion et les modules partagés.
# Bouchons : TelemetryService, CarryService, AntiCheatService, TutorialService (accroche), PvPService.
# Chaque scénario tourne dans son propre luau (état neuf).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a61 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a61}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-screen items boxes tools refused}"
B51="$H/autres-bancs/a51-banc"
B53="$H/autres-bancs/a53-banc"
# Arbre d'avant la fusion de la vague 21 (un autre agent lance run-all-bancs.sh sur son worktree) : rien à
# tester, on le dit et on passe.
if [ ! -f "$SRC/shared/InventoryState.luau" ]; then
	echo "banc a61 (écran d'inventaire) : SAUTÉ, pas de Shared/InventoryState (vague 21 pas encore fusionnée) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/Unbox"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B51/stubs.luau" "$B51/ext29.luau" "$B51/ext38.luau" "$B51/ext46.luau" "$B51/stub-anticheat.luau" "$B51/ext51.luau" "$B53/ext53.luau" "$H/ext61.luau"
		sources
		cat "$B51/features.luau" "$B51/pre.on.luau" "$B51/setup.luau" "$H/setup61.luau" "$H/tests.$name.luau"
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
echo "banc a61 (écran d'inventaire) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
