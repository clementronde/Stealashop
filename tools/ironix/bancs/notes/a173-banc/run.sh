#!/usr/bin/env bash
# Banc hors Studio d'a173 (2026-11-15, vague 53, Play de fusion48) :
#   poursuite (chase.sh, harnais du banc a168) : rappel vers la distance prévue (Chase.HoldRecallGain,
#     HoldRecallMax) à 14, 25 et 60 images/s, images égales (f..) ou variables avec l'élan du Humanoid (j..) :
#     distance gardée 10 ± 0,5, vigile de nuit et policier touchés 1,5 s ± 0,2 après la ruée ; longframe : une
#     image de gel ne fait plus écrire « bloqué sur sa ronde », un vigile vraiment bloqué l'écrit toujours ;
#   potion (harnais a88, tests.potion.luau) : PickPotion avec la tolérance StoreHeistService.ReachPad.
# Arbre sans a173 (pas de HoldRecallGain dans Config/Chase) : « SAUTÉ ». Arbre sans Features.ShelfOpen (a172) :
# la poursuite passe par a172-banc/corrige.sh avec les correctifs du banc a168 (même harnais).
#   bash run.sh [racine du dépôt] [scénarios de chase.sh…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ARG="${1:-/f/StealAShop}"
ROOT="${ARG%/src}"
shift || true
if ! grep -q "HoldRecallGain" "$ROOT/src/shared/Config/Chase.luau" 2>/dev/null; then
	echo "banc a173 SAUTÉ : cet arbre n'a pas encore le rappel de la poursuite à distance"
	echo "banc a173 (rappel de la poursuite, rondes de nuit, potion en courant) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
checks=0
fails=0
add() { # $1 = sortie, $2 = motif de la ligne de total
	local line
	line=$(printf '%s\n' "$1" | grep -E "^$2 : [0-9]+ vérification" | tail -1)
	if [ -z "$line" ]; then
		fails=$((fails + 1))
	else
		checks=$((checks + $(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')))
		fails=$((fails + $(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')))
	fi
}
if grep -q "ShelfOpen = true" "$ROOT/src/shared/Config/Features.luau" 2>/dev/null; then
	out=$(bash "$H/chase.sh" "$ROOT" "$@" 2>&1)
else
	out=$(bash "$H/../a172-banc/corrige.sh" a168 bash "$H/chase.sh" "$ROOT" "$@" 2>&1)
fi
printf '%s\n' "$out"
add "$out" "poursuite"
if [ $# -eq 0 ]; then
	out=$(TESTS_DIR="$H" BANC_LABEL="potion" bash "$H/../a111-banc/autres-bancs/a88-banc/run.sh" "$ROOT" potion 2>&1)
	printf '%s\n' "$out"
	add "$out" "potion"
fi
echo "banc a173 (rappel de la poursuite, rondes de nuit, potion en courant) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
