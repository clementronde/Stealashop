#!/usr/bin/env bash
# Copie a135 (vague 40, 2026-11-14, Cantin : braquage de 6 s) : ../heist-10s.luau remet Balance.Heist.Duration à 10 dans le faux arbre (scénarios de l'ancien déroulé écrits pour 10 s ; la durée est vérifiée par le banc a135). Le reste : copie a66, telle quelle.
# Copie d'a66 (2026-11-11, poursuite sans fin) : G5 et G6 du scénario guard vérifient que le vigile poursuit encore après 22 s et à 130 studs (sans Balance.Guard.GiveUpChaseDuration ; sinon les anciens contrôles : bonne avant et après la fusion).
# Copie d'a36 (vague 12, DEV-060) : bouchon d'AntiCheatService (../stub-anticheat.luau), requis par les services qui déplacent un joueur.
# Banc hors Studio d'a30 (vague 10, DEV-043 et DEV-048) : la batte.
# Vrais : BatService, CarryService, GuardService, StoreHeistService, WindowService, ToolService,
# StatsService, TruckEventService, BatController, HitController, TruckController, Loader, Net,
# Config, Contract, Anim, Format, Types. Bouchons : DataService, NightCycleService (bouclier piloté),
# AnimationController (pistes pilotées), ShatterController. Faux Roblox : stubs.luau (copie de celui
# d'a27, complétée pour le vigile). Chaque scénario tourne dans son propre luau (état neuf) :
# setup.luau puis tests.<nom>.luau, avec pre.<nom>.luau avant setup s'il existe.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a30 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a30}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-tool nobat swing drop guard client trials}"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"

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
		cat "$H/../stub-anticheat.luau" # a36 (DEV-060) : bouchon d'AntiCheatService
		sources
		cat "$H/../heist-10s.luau" # a135 : chrono HEIST de 10 s dans le faux arbre (voir ce fichier)
		cat "$H/../../../a103-banc/ancien-deroule.luau" # a103 (L-112) : ancien déroulé, Features.ShelfOpen forcé à false
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
echo "banc a30 (batte) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
