#!/usr/bin/env bash
# Banc hors Studio d'a206 (vague 63, L-202 point 4, L-192 Q2-Q4) : écran UI_Displayed, réserve, « +$/s » qui vole.
# Trois harnais existants, rien de recopié en dehors de ce dossier :
#   hand      run-core.sh (harnais d'a142 via a203-banc/corrige.sh et a158-banc/corrige.sh, vrai HeldItemService) :
#             retiré à la main = en main ; mains prises (autre objet, outil, mort) = dans la réserve ; TakeDisplayItem
#   displayed autres-bancs/a191 (harnais d'a40, copie a206 du lanceur d'a201) : écran sans OpenButton, couleurs de rareté,
#             Panel.Reserve, Exposer les meilleurs → réserve, DisplayButton, aucun présentoir libre, écran sans Reserve
#   reserve   même harnais : migration d'un profil sans Reserve, nettoyage, plafond, remote validé, retour au jeu
#   fly       autres-bancs/a60 (harnais d'a60, copie a192) : un « +$X/s » qui vole par pose, rien à la première lecture
#             ni en poursuite, GainPop, CounterPop ou texte simple
# Arbre sans Config/Displayed (avant a206) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if [ ! -f "$ROOT/src/shared/Config/Displayed.luau" ]; then
	echo "banc a206 (présentoirs, réserve, revenu qui vole) : SAUTÉ, a206 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
total_checks=0
total_fails=0
part() {
	local label="$1"
	shift
	local out line c f
	out=$("$@" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|arrêté avant la fin" || true
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
		echo "  $label : pas de résumé"
		total_fails=$((total_fails + 1))
		return
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/; s/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $label : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
}
part "hand" bash "$N/a203-banc/corrige.sh" a206 "$H/run-core-a158.sh" "$ROOT" hand
part "displayed, reserve" bash "$H/autres-bancs/a191/run.sh" "$ROOT" displayed reserve
part "fly" bash "$H/autres-bancs/a60/run.sh" "$ROOT" fly
echo "banc a206 (présentoirs, réserve, revenu qui vole) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
