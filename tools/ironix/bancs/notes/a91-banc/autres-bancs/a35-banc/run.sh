#!/usr/bin/env bash
# Copie d'a91 (vague 29, 2026-11-12, L-106 point 12 et L-107 point 1) : délai d'1 s par plaque (PAD_COOLDOWN), AmountGui caché à $0,
# BillboardGui ou SurfaceGui. Sur un arbre sans PAD_COOLDOWN dans DisplayService, relance la copie d'a72 : bonne avant et après la fusion.
if ! grep -q "PAD_COOLDOWN" "${1:-/f/StealAShop}/src/server/Services/DisplayService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a72-banc/autres-bancs/a35-banc/run.sh" "$@"; fi
# Copie d'a72 (vague 24, 2026-11-11) : une sortie de plaque de moins de 0,3 s ne compte plus (un seul ramassage par arrivée) :
# cashOut (setup.luau) reste 0,4 s hors de la plaque au lieu de 0,15 s ; stub-anticheat lu dans a59-banc/autres-bancs.
# Sur un arbre sans PAD_EXIT_MARGIN dans DisplayService, relance la copie d'a59 : bonne avant et après la fusion.
if ! grep -q "PAD_EXIT_MARGIN" "${1:-/f/StealAShop}/src/server/Services/DisplayService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a59-banc/autres-bancs/a35-banc/run.sh" "$@"; fi
# Copie d'a59 (2026-11-10, L-091) : plus de tapis de caisse CashPad ; la boutique du banc a une seule plaque CollectPad_01 (là où était le tapis), qui reçoit l'argent de tous les présentoirs. Sur un arbre d'avant a59 (CollectPad_xx absent de Contract/Models), relance la copie d'a51 : bonne avant et après la fusion.
if ! grep -q "CollectPad_%02d" "${1:-/f/StealAShop}/src/shared/Contract/Models.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a51-banc/autres-bancs/a35-banc/run.sh" "$@"; fi
# Copie d'a51 (2026-11-09, L-089) : le faux UnboxService gagne OnBoxStowed et GetBoxPosition (TutorialService s'y abonne depuis L-089 : colis rangé dans l'inventaire, funnel 5).
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance la copie précédente (a46-banc/autres-bancs/a35-banc) : bonne avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../../" && pwd)/a46-banc/autres-bancs/a35-banc/run.sh" "$@"; fi
# Copie d'a46 (2026-11-08, L-086) : plus d'amélioration UnboxBenches, le scénario economy achète un présentoir de plus à la place ; ../stub-anticheat.luau rangé dans a46-banc/autres-bancs.
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a36-banc/autres-bancs/a35-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a36-banc/autres-bancs/a35-banc/run.sh" "$@"; fi
# Copie d'a36 (vague 12, DEV-060) : bouchon d'AntiCheatService (../stub-anticheat.luau), requis par les services qui déplacent un joueur.
# Banc hors Studio d'a35 (vague 12, DEV-054) : la télémétrie (TelemetryService, Config/Telemetry,
# événement OnPurchase de ShopService, interrupteur du funnel de TutorialService).
# Vrais : TelemetryService, ShopService, TutorialService, PvPService, BatService, StatsService,
# DisplayService, PlotService, WindowService, CarryService, Loader, Net, Config, Contract, Anim, Format,
# Types. Bouchons : DataService, NightCycleService, ToolService, CosmeticService, UnboxService,
# GuardService, StoreHeistService (setup.luau). Faux Roblox : celui d'a30 (stubs.luau), complété par
# ext29.luau (a29), ext32.luau (a32) et ext35.luau (énumérations de l'Analytics, faux AnalyticsService
# qui note et vérifie chaque appel, serveur « prod »).
# Chaque scénario tourne dans son propre luau (état neuf) : pre.<nom>.luau s'il existe, setup.luau,
# puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a35 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a35}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-economy custom refusal prod switch hooks funnel names badnames}"
FILES="shared server/Services/TelemetryService.luau server/Services/ShopService.luau server/Services/TutorialService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext32.luau" "$H/ext35.luau"
		cat "$H/../../../a59-banc/autres-bancs/stub-anticheat.luau" # a36 (DEV-060) : bouchon d'AntiCheatService
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$H/setup.luau"
		cat "$H/tests.$name.luau"
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
echo "banc a35 (télémétrie) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
