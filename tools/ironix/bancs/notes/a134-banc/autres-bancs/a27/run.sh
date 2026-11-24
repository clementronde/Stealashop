#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : PV du camion = 100 × dégâts conseillés de sa zone (1000 PV fixes avant), 5 coups par seconde en débit régulier.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a97-banc/autres-bancs/a27-banc/run.sh" "$@"; fi
# Copie d'a97 (2026-11-12, vague 29, L-105 point 2) : le camion livré debout (celui du banc : 12,6 de large, 15,8 de
# haut) est couché à sa place : 15,8 studs de large. B6 attend un bord à 7,9 studs du milieu (22 studs libres devant
# chaque vitrine) ; C15 recule Alice de 1,6 stud (9,2 studs du flanc couché) ; D30 : demi-hauteur des pièces couchées 3,15. Sur un arbre sans ArriveUpright
# (a97 pas encore fusionné), relance la copie précédente (a51-banc/autres-bancs/a27-banc) : bonne avant et après la fusion.
if ! grep -q ArriveUpright "${1:-/f/StealAShop}/src/server/Services/TruckEventService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a51-banc/autres-bancs/a27-banc/run.sh" "$@"; fi
# Copie d'a51 (2026-11-09, L-089) : le colis du camion ramassé entre dans l'inventaire dès que le porteur entre dans la zone safe (E12 à E14 : plus de PlaceBox sur un présentoir), braquage compté à ce moment-là.
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance la copie précédente (a46-banc/autres-bancs/a27-banc) : bonne avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../../" && pwd)/a46-banc/autres-bancs/a27-banc/run.sh" "$@"; fi
# Copie d'a46 (2026-11-08, L-086) : le colis du camion se pose sur un présentoir (DisplaySlot_xx à la place des UnboxBench_xx du faux plot ; faux DisplayService avec GetSlots, GetSlotStates, PlaceItem, HasRoom).
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a42-banc/autres-bancs/a27-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a42-banc/autres-bancs/a27-banc/run.sh" "$@"; fi
# Banc hors Studio d'a27 (vague 9) : l'événement camion (liaison L-049).
# Copie a42 (vague 14) : une seule invite allumée quand plusieurs colis du camion sont à portée → D22 et D26 regardent depuis plus loin (Alice hors de portée).
# Copie a34 (vague 12, DEV-053) : C5 attend maintenant WindowHit pour le camion (dégâts flottants, son du coup).
# Vrais : TruckEventService, WindowService, CarryService, UnboxService, ContractChecker,
# HitController, TruckController, Loader, Net, Config, Contract, Format, Types. Bouchons :
# ToolService, StatsService, NightCycleService (phase pilotée), DataService, PlotService,
# DisplayService, AnimationController, ShatterController. Faux Roblox : stubs.luau.
# Chaque scénario tourne dans son propre luau (état neuf) : setup.luau puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a27 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a27}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-contract schedule hits explosion grab hook prod off}"
FILES="shared server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/UnboxService.luau server/Services/ContractChecker.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau"
		cat "$H/../../../a97-banc/../a36-banc/autres-bancs/stub-anticheat.luau" # correctif DEV-060 du 2026-11-08
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$H/setup.luau"
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
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
echo "banc a27 (camion) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
