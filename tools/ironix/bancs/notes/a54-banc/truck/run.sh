#!/usr/bin/env bash
# a54 (2026-11-10, vague 20, L-083 point 3) : copie du banc a42 (stubs.luau et setup.luau, plus un bouchon
# GuardService qui note StartDriverChase) pour la fin du chrono du camion : scénarios chase et noguard.
# Ce qui suit est l'en-tête d'origine d'a42.
# Banc hors Studio d'a42 (vague 14, liaison L-071 points 6 à 9, et colis du camion qui se chevauchaient) :
# poursuite (UI_Chase, ChaseController), musiques d'événement (MUS_Chase, MUS_Truck, MusicController),
# sons et conducteurs du camion (TruckController, TruckEventService), écart entre les colis lâchés et
# invite du colis visé, bandeau de secours et branchement de UI_Notify (NotifyController), panneaux des
# arches (ZoneGateController, BB_ZoneGate, Shared/AdvicePanel commun avec StoreInfoController), contrat
# (Contract/UI, Contract/Models, Contract/Animations lus par le vrai ContractChecker).
# Vrais : Config, Contract, Format, AdvicePanel, Loader, Net, Anim, les contrôleurs et services cités,
# UI/Motion, WindowService, CarryService, ContractChecker. Bouchons : ToolService, StatsService,
# NightCycleService, AnimationController. Faux Roblox : stubs.luau (copie de celui d'a33, complétée).
# Chaque scénario tourne dans son propre luau (état neuf) : pre.<nom>.luau s'il existe, setup.luau,
# puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a42 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a54}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-chase noguard}"
FILES="shared client/Controllers/UI client/Controllers/ChaseController.luau client/Controllers/MusicController.luau client/Controllers/NotifyController.luau client/Controllers/ZoneGateController.luau client/Controllers/StoreInfoController.luau client/Controllers/TruckController.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/ContractChecker.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau"
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
echo "banc a54-truck (fin du chrono, conducteurs lancés) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
