#!/usr/bin/env bash
# Copie d'a37 (2026-11-08, DEV-052) : TheftAlertController requiert Controllers/UI/Motion → module UI/Motion ajouté à l'arbre (setup.luau) ; le faux Roblox d'a30 a déjà un TweenService instantané (vérifications d'origine inchangées).
# Copie d'a36 (vague 12, DEV-060) : bouchon d'AntiCheatService (../stub-anticheat.luau), requis par les services qui déplacent un joueur.
# Banc hors Studio d'a32 (vague 11, DEV-042) : l'alerte de la victime d'un vol et l'Adrénaline.
# Vrais : TheftAlertService, PvPService, BatService, StatsService, DisplayService, PlotService,
# WindowService, CarryService (serveur) ; TheftAlertController, BatController, ShelfBoxController
# (client) ; Loader, Net, Config, Contract, Anim, Format, Types. Bouchons : DataService (profils,
# sauvegarde simulée), NightCycleService (bouclier débutant), ToolService (dégâts, batte en main) ;
# client : AnimationController. Faux Roblox : celui d'a30 (stubs.luau), complété par ext29.luau
# (a29) et ext32.luau (sons, caméra).
# Chaque scénario tourne dans son propre luau (état neuf) : setup.luau puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a32 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a37}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-alert screen adrenaline defense limit motion}" # motion : ajout a37 (DEV-052)
FILES="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/TheftAlertService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/TheftAlertController.luau client/Controllers/BatController.luau client/Controllers/ShelfBoxController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext32.luau"
		cat "$H/../stub-anticheat.luau" # a36 (DEV-060) : bouchon d'AntiCheatService
		sources
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
echo "banc a32 (alerte de la victime) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
