#!/usr/bin/env bash
# Copie d'a53 (2026-11-09, DEV-101) : profil v8 (Rewards) → version attendue PV = 8 quand Types/Profile a « Rewards: Rewards », 7 sinon (migration) ; bonne avant et après la fusion.
# Copie d'a51 (2026-11-09, L-089) : profil v7 (colis rangés par uid dans l'inventaire, plus de BoxQueue) → version attendue v7 quand l'arbre a InventoryService ; les colis du profil v5 retrouvés dans l'inventaire.
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance le banc d'origine (a48-banc) : bon avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a48-banc/run.sh" "$@"; fi
# Banc hors Studio d'a48 (DEV-102, gains hors ligne) : profil v6 (Offline = heure et revenu de la dernière
# présence) et migration v5 → v6 ; au retour, absence (bornée à Config/Offline.MaxHours) × revenu au départ
# (bonus permanents compris, boost ×2 argent exclu) × Rate, versé dans la caisse (CashRegister), encaissé
# au CashPad ; message Notify ; télémétrie « Offline » (vrai TelemetryService, AnalyticsService faux d'a35) ;
# heure inconnue, dans le futur, horloge qui recule ; crochet de Studio OfflineTest.
# Repris du banc a46 (faux Roblox : stubs.luau d'a36 avec os.time() réglable par OS_TIME_OFFSET, ext29,
# ext38, ext46, ext35 d'a35 ; mise en place setup.luau d'a46 adaptée).
# Vrais : OfflineService, TelemetryService, DataService (faux ProfileStore d'ext38), DisplayService,
# PlotService, UnboxService, MonetizationService, IndexService, TrainingService, StatsService, ToolService,
# ShopService, Loader, Net, Config, Contract, Format, Types. Bouchons : CarryService, AntiCheatService,
# TutorialService, PvPService, BatService, GuardService, NightCycleService.
# Chaque scénario tourne dans son propre luau (état neuf).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a48 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a48}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-migration gain bonus security}"
# Arbre d'avant la fusion de DEV-102 : rien à tester, on le dit et on passe.
if [ ! -f "$SRC/server/Services/OfflineService.luau" ]; then
	echo "banc a48 (gains hors ligne) : SAUTÉ, pas d'OfflineService (DEV-102 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/OfflineService.luau server/Services/TelemetryService.luau client/Controllers/UnboxController.luau client/Controllers/Unbox"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext38.luau" "$H/ext46.luau" "$H/ext35.luau" "$H/stub-anticheat.luau"
		sources
		cat "$H/features.luau" "$H/pre.on.luau" "$H/setup.luau" "$H/helpers.luau" "$H/tests.$name.luau"
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
echo "banc a48 (gains hors ligne) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
