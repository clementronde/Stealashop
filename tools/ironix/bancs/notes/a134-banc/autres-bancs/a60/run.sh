#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : plus de gain « +X Power » (plus de banc ni de Force) ; faux arbre : levier-force.luau et coups-en-rafale.luau.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a62-banc/autres-bancs/a60-banc/run.sh" "$@"; fi
# Copie d'a62 (2026-11-11, vague 22, L-092 3g) : ext-a60.luau ajoute les signaux InputBegan et InputEnded
# (Motion.Button suit la fin du toucher). Tests inchangés.
# Banc hors Studio d'a60 (vague 21, L-091 points 3 et 7 : gains qui volent, animations d'UI dans tout
# le jeu). Faux Roblox : celui d'a37 (stubs.luau, ext-motion.luau, setup.luau copiés d'a37-banc),
# complété par ext-a60.luau (MouseButton1Down/Up, TextBounds, UDim2 avec arithmétique et tweens de
# UDim2). Vraies sources : Shared, Controllers/UI (Motion), HudController, GainController,
# UiFeelController ; HeistController, ChaseController et RewardsController bouchonnés.
# Scénarios (chacun dans son propre luau) : motion (boutons, cartes, sursaut), gains (tapis, banc,
# ramassage, récompense, autre gain, regroupement), feel (branchement des écrans, poursuite), timer
# (TimerTick du HUD).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a60 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-motion gains feel timer}"
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau"
if [ ! -f "$SRC/client/Controllers/GainController.luau" ]; then
	echo "banc a60 (gains qui volent, animations d'UI) : SAUTÉ, pas de Controllers/GainController.luau dans $SRC (vague 21 pas encore fusionnée) : 0 vérification(s), 0 échec(s)"
	exit 0
fi

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		cat "$H/stubs.luau" "$H/ext-motion.luau" "$H/ext-a60.luau"
		sources
		cat "$H/../../levier-force.luau" # a134 : faux arbre, voir ce fichier
		cat "$H/../../coups-en-rafale.luau" # a134 : faux arbre, voir ce fichier
		cat "$H/setup.luau" "$H/setup-a60.luau"
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a60 (gains qui volent, animations d'UI) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
