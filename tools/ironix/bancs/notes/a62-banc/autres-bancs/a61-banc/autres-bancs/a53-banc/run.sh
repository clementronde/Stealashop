#!/usr/bin/env bash
# Copie d'a61 (2026-11-10, vague 21, L-079 : plus de Tool de colis ni d'objet) : scénario daily, le colis offert
# est lu dans l'attribut InventoryState du Player (invOf, ajouté à setup53.luau). Sur un arbre sans
# src/shared/InventoryState.luau, relance le banc a53 d'origine : bon avant et après la fusion.
# Banc hors Studio d'a53 (DEV-101, vague 19, 2026-11-09) : récompenses quotidiennes (calendrier de 7 jours,
# minuit UTC, jour manqué) et de temps de jeu (paliers 5, 15, 30, 60 min dans la journée), RewardService,
# colis offert dans l'inventaire (UnboxService.GiveBox, inventaire plein), boost ×2 argent boutique Robux
# coupée (MonetizationService), télémétrie, profil v8 et migration v7 → v8, RewardsController (UI_Rewards).
# Faux Roblox d'a51 (stubs.luau d'a36, ext29, ext38, ext46, ext51), complété par ext53.luau
# (ScrollingFrame, InputBegan) ; mise en place setup51.luau (copie telle quelle de celle d'a51) puis
# setup53.luau (RewardService, RewardsController, UI/Motion, écrans du relevé de Clément).
# Vrais : RewardService, InventoryService, IndexService, MonetizationService, DataService (faux ProfileStore
# d'ext38), DisplayService, PlotService, UnboxService, TrainingService, StatsService, ToolService,
# ShopService, RewardsController, Motion, InventoryController, UnboxController et les modules partagés.
# Bouchons : TelemetryService (noté), CarryService, AntiCheatService, TutorialService, PvPService.
# Chaque scénario tourne dans son propre luau (état neuf).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a53 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a53}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-daily midnight playtime full boost migration client}"
# Arbre d'avant la fusion de DEV-101 : rien à tester, on le dit et on passe.
if [ ! -f "$SRC/server/Services/RewardService.luau" ]; then
	echo "banc a53 (récompenses) : SAUTÉ, pas de RewardService (DEV-101 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
if [ ! -f "$SRC/shared/InventoryState.luau" ]; then
	exec bash "$H/../../../a53-banc/run.sh" "$ROOT" "$@"
fi
FILES="shared server/Services/RewardService.luau server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/RewardsController.luau client/Controllers/UI client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/Unbox"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext38.luau" "$H/ext46.luau" "$H/stub-anticheat.luau" "$H/ext51.luau" "$H/ext53.luau"
		sources
		cat "$H/features.luau" "$H/setup51.luau" "$H/setup53.luau" "$H/tests.$name.luau"
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
echo "banc a53 (récompenses) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
