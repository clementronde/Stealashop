#!/usr/bin/env bash
# a90 (2026-11-12) : alerte des caméras en « Alert » acceptée (tests.cameras.luau, ligne 34) ; sans la tuile Walls, lance la copie d'a90 (celle d'a88 + « Alert »).
# Copie d'a93 (2026-11-12, vague 29, L-105 point 3, L-106 points 2 et 3) du banc a84 (version a88) : la tuile
# ShopLevel devient Walls (SKILL_IDS, refus « Soon » sur Traps fermée par Walls 2), les PV de la porte viennent
# du niveau de boutique StageLevel (startSkills pose StageLevel = 2 : base 500, comme avant), migration
# ShopLevel → Walls au chargement (load), Walls × Glass sur la même barre et mur visible (scénario walls, lancé par a93-banc/run.sh ;
# ShopWallsService). Sans la tuile Walls dans Config/SkillTree (avant la fusion d'a93), lance le banc d'origine.
# Banc hors Studio d'a84 (2026-11-11, vague 27, L-096 point 2) : arbre de compétences côté serveur.
# Vrais : SkillTreeService, PvPService, WindowService, DisplayService, PlotService, CarryService, Net,
# Config, Contract, Format, Types, Loader ; client : CameraAlertController, PvPController. Bouchons : ceux
# du banc a29 (copie d'a36 : DataService, NightCycleService, ToolService, StatsService, AntiCheatService),
# plus TelemetryService (pre84.luau : appels notés). Faux Roblox et mise en place lus sur place dans
# a36-banc/autres-bancs/a29-banc (stubs.luau, ext29.luau, setup.luau).
# Scénarios : buy (achats acceptés et refusés, attributs, télémétrie, OnChanged), load (profil nettoyé),
# effects (Glass, Glass Regen, Safe), cameras (alerte N1, surlignage N2 côté client, test Studio).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a84 ; après fusion : /f/StealAShop)
# Avant la fusion d'a84 : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A29="$H/../../../a36-banc/autres-bancs/a29-banc"
ROOT="${1:-/f/StealAShop/agents/a84}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-buy load effects cameras}"
if ! grep -q "Id = \"Walls\"" "$SRC/shared/Config/SkillTree.luau" 2>/dev/null; then
	exec bash "$H/../../../a90-banc/autres-bancs/a84-banc/run.sh" "$ROOT" "$@"
fi
if [ ! -f "$SRC/server/Services/SkillTreeService.luau" ]; then
	echo "banc a84 SAUTÉ : cet arbre n'a pas encore SkillTreeService"
	echo "banc a84 (arbre de compétences, serveur) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A29/stubs.luau" "$A29/ext29.luau"
		cat "$A29/../stub-anticheat.luau"
		sources
		cat "$H/pre84.luau"
		cat "$A29/setup.luau"
		cat "$H/lib84.luau"
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
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a84 (arbre de compétences, serveur) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
