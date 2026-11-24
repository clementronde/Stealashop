#!/usr/bin/env bash
# a172 (2026-11-15, vague 53) : copie du lanceur d'a171-banc (corrige.sh et patches lus là-bas). Scénario a49/heist retiré :
# il comptait les mutations tirées à la MISE EN RAYON (ancien déroulé, Features.ShelfOpen forcé à false par le faux arbre du banc
# a17-heist) ; ce tirage est parti avec l'interrupteur (drawContent). La mutation est tirée à la sortie de l'objet : bancs a103
# (open) et a109 (draw). Arbre avec Features.ShelfOpen : le banc tel quel.
if grep -q "ShelfOpen = true" "${1:-/f/StealAShop}/src/shared/Config/Features.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a171-banc/run.sh" "$@"; fi
# Banc a171 (vague 52, 2026-11-15) : la couverture des bancs après a158 (le colis porté n'existe plus). Scénarios que a158 avait
# retirés alors qu'ils vérifiaient au passage une règle qui existe encore, relancés AVEC UN OBJET (NPCItem, objet sous antivol)
# par corrige.sh (corrections d'a158, puis patches/<banc>.<scénario>.sed et .pre.luau d'a171 ; en-tête de chaque fichier).
#   barre du bas     a74 slots use ; a76 stable drag save phone dblclick
#   inventaire       a61 items ; a51 inventory (lancé sans Features.ShelfOpen forcé à false : run-base.sh)
#   index            a40 discover off (run-base.sh) ; a55 reward
#   mutations        a49 stand heist (run-base.sh)
#   boutique Robux   a38 off effects offers studio client (attentes de colis retirées ; l'antivol : banc a105)
#   batte, vigile    a30 drop guard (inner/a30.sh) ; a146 catch
#   Fortune Tower    a123 hook prodon (colis au sol retirés)
# Avant a158 (NPCBoxPayload encore dans Types/Carry) : SAUTÉ (les bancs d'origine tournent tels quels).
#   bash run.sh [racine du dépôt]
# a172 : tout le banc passe par a172-banc/corrige.sh (patches/a171.sed, textes « No item is waiting ») ; A172_IN évite de boucler.
if [ -z "${A172_IN:-}" ]; then A172_IN=1 exec bash "$(cd "$(dirname "$0")/../.." && pwd)/corrige.sh" a171 bash "$0" "$@"; fi
set -u
H="$(cd "$(dirname "$0")/../../../a171-banc" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if grep -q "NPCBoxPayload = {" "$ROOT/src/shared/Types/Carry.luau" 2>/dev/null; then
	echo "banc a171 (couverture après a158) : SAUTÉ, a158 pas dans l'arbre : 0 vérification(s), 0 échec(s)"
	exit 0
fi
total_checks=0
total_fails=0
one() { # $1 = banc, $2 = scénario, puis la commande du banc
	local banc="$1" scen="$2"
	shift 2
	local out line c f
	out="$(A171_SCEN="$scen" bash "$H/corrige.sh" "$banc" "$@" 2>&1)"
	line="$(printf '%s\n' "$out" | grep -E "^  $scen : [0-9]+ contrôles, [0-9]+ raté\(s\)$" | tail -1)"
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | grep -E "ÉCHEC|luau:[0-9]+" | head -8
		echo "  $banc/$scen : arrêté avant la fin"
		total_fails=$((total_fails + 1))
		return
	fi
	printf '%s\n' "$out" | grep -E "ÉCHEC" | sed "s#^#  $banc/$scen #" || true
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) contrôles.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) raté.*/\1/')
	echo "  $banc/$scen : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
}
for s in slots use; do one a74 $s bash "$N/a142-banc/autres-bancs/a74-banc/run.sh" "$ROOT" $s; done
for s in stable drag save phone dblclick; do one a76 $s bash "$N/a142-banc/autres-bancs/a76-banc/run.sh" "$ROOT" $s; done
one a61 items bash "$N/a118-banc/autres-bancs/a61-banc/run.sh" "$ROOT" items
one a51 inventory bash "$N/a105-banc/autres-bancs/a51-banc/run-base.sh" "$ROOT" inventory
for s in discover off; do one a40 $s bash "$N/a117-banc/autres-bancs/a40-banc/run-base.sh" "$ROOT" $s; done
one a55 reward bash "$N/a117-banc/autres-bancs/a55-banc/run.sh" "$ROOT" reward
for s in stand; do one a49 $s bash "$N/a134-banc/autres-bancs/a49/run-base.sh" "$ROOT" $s; done
for s in off effects offers studio client; do one a38 $s bash "$N/a134-banc/autres-bancs/a38/run.sh" "$ROOT" $s; done
for s in drop guard; do export A171_A30=$s; one a30 $s bash "$N/a153-banc/regle-coupee.sh" "$H/inner/a30.sh" repo "$ROOT"; done
one a146 catch bash "$N/a146-banc/run.sh" "$ROOT" catch
for s in hook prodon; do one a123 $s bash "$N/a148-banc/autres-bancs/a123/run.sh" "$ROOT" $s; done
echo "banc a171 (couverture après a158) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
