#!/usr/bin/env bash
# Banc hors Studio d'a37 (DEV-052, animations d'UI) : le module client Controllers/UI/Motion
# (ouverture, fermeture, réouverture pendant la fermeture, Show/Hide d'éléments, chiffres qui
# défilent, aucun changement durable des propriétés de Clément) et son branchement dans le vrai
# HudController (Cash et Income qui défilent, revenu retenu, HeistTimer et GuardMeter).
# Faux Roblox : celui d'a15 (stubs.luau, copie inchangée de a26-banc/a23-banc/autres-bancs/a15-banc),
# complété par ext-motion.luau (UIScale, NumberValue, GetPropertyChangedSignal, TweenInfo,
# TweenService simulé dans le temps, avec les vraies courbes). Vraies sources : Shared (Config,
# Contract, Net, Format…), Controllers/UI, HudController ; HeistController et ChaseController
# bouchonnés (pilotables).
# Chaque scénario tourne dans son propre luau (état neuf) : setup.luau puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a37 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a37}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-motion hud}"
FILES="shared client/Controllers/UI client/Controllers/HudController.luau"
# Arbre d'avant la fusion de DEV-052 (un autre agent lance run-all-bancs.sh sur son worktree) :
# rien à tester, on le dit et on passe.
if [ ! -f "$SRC/client/Controllers/UI/Motion.luau" ]; then
	echo "banc a37 (animations d'UI) : SAUTÉ, pas de Controllers/UI/Motion.luau dans $SRC (DEV-052 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
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
		cat "$H/stubs.luau" "$H/ext-motion.luau"
		sources
		cat "$H/setup.luau"
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
echo "banc a37 (animations d'UI) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
