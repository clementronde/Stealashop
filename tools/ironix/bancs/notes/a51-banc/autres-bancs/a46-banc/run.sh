#!/usr/bin/env bash
# Copie d'a51 (2026-11-09, L-089) : plus de colis sur les présentoirs (L-086 remplacé) : seul le scénario « contract » (UnboxBench_xx et VaultSlot_xx facultatifs et muets) reste ; « stand », « client » et « migration » (v4 → v5) sont repris par le banc a51 (place, open, client, migration v4 et v6 → v7).
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance la copie précédente (a48-banc/autres-bancs/a46-banc) : bonne avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../../" && pwd)/a48-banc/autres-bancs/a46-banc/run.sh" "$@"; fi
# Copie d'a48 (2026-11-08, DEV-102) : profil v6 (Offline, gains hors ligne) → version attendue v6 quand Types/Profile a « Offline: Offline ».
# a48 : sur un arbre sans Offline dans Types/Profile, relance la copie précédente (a46-banc) : bonne avant et après la fusion.
if ! grep -q "Offline: Offline" "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a46-banc/run.sh" "$@"; fi
# Banc hors Studio d'a46 (L-086, vague 16) : on pose et on ouvre les colis directement sur les
# présentoirs (DisplaySlot_xx), plus d'établis ; profil v5 (Boxes par présentoir, BoxQueue) et
# migration v4 → v5 ; UnboxBench_xx et VaultSlot_xx facultatifs et muets au contrat ; invites
# « Place Box » / « Open » du client sur les présentoirs.
# Repris du banc a40 (faux Roblox : stubs.luau d'a36, ext29.luau, ext38.luau ; mise en place
# setup.luau adaptée : plus de placeBox sur un établi).
# Vrais : DataService (faux ProfileStore d'ext38), DisplayService, PlotService, UnboxService,
# MonetizationService, IndexService, TrainingService, StatsService, ToolService, ShopService,
# ContractChecker (scénario contract), UnboxController et ses modules (scénario client), Loader, Net,
# Config, Contract, Format, Types. Bouchons : TelemetryService, CarryService, AntiCheatService,
# TutorialService (accroche du colis du tuto), PvPService.
# Chaque scénario tourne dans son propre luau (état neuf).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a46 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a46}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-contract}" # a51 : stand, client et migration repris par le banc a51
# Arbre d'avant la fusion de L-086 (un autre agent lance run-all-bancs.sh sur son worktree) : rien à
# tester, on le dit et on passe.
if ! grep -q "BoxQueue" "$SRC/shared/Types/Profile.luau" 2>/dev/null; then
	echo "banc a46 (colis sur les présentoirs) : SAUTÉ, pas de BoxQueue dans Types/Profile (L-086 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/ContractChecker.luau client/Controllers/UnboxController.luau client/Controllers/Unbox"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext38.luau" "$H/ext46.luau" "$H/stub-anticheat.luau"
		sources
		cat "$H/features.luau" "$H/pre.on.luau" "$H/setup.luau" "$H/tests.$name.luau"
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
echo "banc a46 (colis sur les présentoirs) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
