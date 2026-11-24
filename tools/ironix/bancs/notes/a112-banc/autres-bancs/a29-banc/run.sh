#!/usr/bin/env bash
# Copie d'a112 (2026-11-13, vague 33, Cantin : plus de chrono chez un joueur, alerte d'intrusion) : flow (ni StealEndsAt ni
# HeistTimer, panneau « OPEN », TheftAlert(true, Bob, nil) à la casse avant celui de l'objet), eject (porte cassée tant qu'un
# intrus est dedans, même après 100 s, puis refaite une fois vide), edges (toujours ouverte après 10 s). Sans
# PvPService.GetIntruders dans l'arbre, lance la copie d'a99 (bonne avant la fusion).
# Copie d'a99 (2026-11-12, décision de Cantin : plus aucune protection des boutiques, défense par le propriétaire) : rules (règles 1, 3 et 4 retournées : on vole une débutante, juste après un vol, et un riche vole un pauvre), flow (plus d'immunité ni de « protected » au vol), fails (mort dans la boutique d'Ada : 60 s d'interdiction, puis la suite), stress (attend la fin d'une interdiction au lieu de l'immunité). Sans PvP.KickRobCooldown dans l'arbre, lance la copie d'a93 (bonne avant et après la fusion).
# Copie d'a93 (2026-11-12, vague 29, L-106 point 3) : PV de la porte = base du niveau de boutique (StageLevel absent = 1 : 50 PV) et non plus 50 × les dégâts du propriétaire ; flow et edges attendent « HP 50 ». Faux Roblox et mise en place lus dans le banc d'origine (a36-banc/autres-bancs/a29-banc). Sans la nouvelle formule, lance le banc d'origine.
# Copie d'a36 (vague 12, DEV-060) : bouchon d'AntiCheatService (../stub-anticheat.luau), requis par les services qui déplacent un joueur.
# Banc hors Studio d'a29 (vague 10) : vol entre joueurs (DEV-041), protections anti-frustration
# (DEV-044), panneau de repérage (fin de DEV-040) et sortie des boutiques du hub (L-050).
# Vrais : PvPService, DisplayService, PlotService, WindowService, CarryService, PvPController, Loader,
# Net, Config, Contract, Format, Types. Bouchons : DataService (profils, sauvegarde simulée),
# NightCycleService (bouclier débutant), ToolService, StatsService ; client : WindowController,
# AnimationController. Faux Roblox : celui d'a27 (stubs.luau), complété dans ext29.luau.
# Chaque scénario tourne dans son propre luau (état neuf) : setup.luau puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a29 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
O="$H/../../../a36-banc/autres-bancs/a29-banc" # banc d'origine (faux Roblox, mise en place)
ROOT="${1:-/f/StealAShop/agents/a29}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-flow fails rules eject stress edges}"
if ! grep -q "function PvPService.GetIntruders" "$SRC/server/Services/PvPService.luau" 2>/dev/null; then
	exec bash "$H/../../../a99-banc/autres-bancs/a29-banc/run.sh" "$ROOT" "$@"
fi
if ! grep -q "KickRobCooldown" "$SRC/shared/Config/PvP.luau" 2>/dev/null; then
	exec bash "$H/../../../a93-banc/autres-bancs/a29-banc/run.sh" "$ROOT" "$@"
fi
if ! grep -q "function Formulas.PlayerWindowHP(stageLevel" "$SRC/shared/Config/Formulas.luau" 2>/dev/null; then
	exec bash "$O/run.sh" "$ROOT" "$@"
fi
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/PvPController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$O/stubs.luau" "$O/ext29.luau"
		cat "$O/../stub-anticheat.luau" # a36 (DEV-060) : bouchon d'AntiCheatService
		sources
		cat "$O/setup.luau"
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
echo "banc a29 (vol entre joueurs) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
