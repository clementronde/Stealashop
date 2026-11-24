#!/usr/bin/env bash
# Copie a147 (2026-11-14, vague 41) du runner de la copie a134 du banc a36 : mêmes fichiers (lus dans a134-banc/autres-bancs/a36),
# plus le faux arbre a147-banc/retour-base-actif.luau (Features.ReturnToBase remis à true dans le faux arbre : les tests
# du téléport du retour à la base, C2a, L6a et O2a, restent valables tant que ReturnBaseService existe).
# Arbre où ReturnToBase est encore à true (avant a147) : la copie a134 tourne telle quelle.
if grep -q "ReturnToBase = true" "${1:-/f/StealAShop}/src/shared/Config/Features.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a134-banc/autres-bancs/a36/run.sh" "$@"; fi
# Banc hors Studio d'a36 (vague 12, DEV-060) : AntiCheatService, contrôle des déplacements.
# Vrais : AntiCheatService, CarryService, StatsService, StoreHeistService, WindowService, ToolService,
# BatService, GuardService, PlotService, ReturnBaseService, TrainingService, PvPService,
# DisplayService, NightCycleService, Loader, Net, Config, Contract, Anim, Format, Types. Bouchon :
# DataService. Faux Roblox : celui d'a30 (stubs.luau) + ext29.luau (a29) + ext36.luau. Client simulé
# (latence, rafales, gel du réseau) : setup.luau. Chaque scénario tourne dans son propre luau (état
# neuf) : pre.<nom>.luau s'il existe, setup.luau, puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a36 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
ME="$(cd "$(dirname "$0")" && pwd)"
H="$ME/../../../a134-banc/autres-bancs/a36"
ROOT="${1:-/f/StealAShop/agents/a65}"
shift || true
SRC="$ROOT/src"
if ! grep -q "function PvPService.GetIntruders" "$SRC/server/Services/PvPService.luau" 2>/dev/null; then
	exec bash "$H/../../../a65-banc/autres-bancs/a36-banc/run.sh" "$ROOT" "$@"
fi
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -qE "USE_ZONE|TrainingZone" "$SRC/server/Services/TrainingService.luau" 2>/dev/null; then
	exec bash "$H/../../../a41-banc/autres-bancs/a36-banc/run.sh" "$ROOT" "$@"
fi
SCENARIOS="${*:-detect stolen code speed lag push modes prod off}"
FILES="shared server/Services/AntiCheatService.luau server/Services/CarryService.luau server/Services/StatsService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/BatService.luau server/Services/GuardService.luau server/Services/PlotService.luau server/Services/ReturnBaseService.luau server/Services/TrainingService.luau server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/NightCycleService.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	tests="$H/tests.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext36.luau"
		sources
		cat "$ME/../../retour-base-actif.luau" # a147 : Features.ReturnToBase à true dans le faux arbre
		cat "$H/../../levier-force.luau" # a134 : faux arbre, voir ce fichier
		cat "$H/../../coups-en-rafale.luau" # a134 : faux arbre, voir ce fichier
		cat "$H/../../../a115-banc/../a103-banc/ancien-deroule.luau" # a103 (L-112) : ancien déroulé, Features.ShelfOpen forcé à false
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$H/setup.luau"
		cat "$tests"
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
echo "banc a36 (anti-triche) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
