#!/usr/bin/env bash
# Banc hors Studio d a242 (vague 72, L-219 point 4, L-231, L-213 ; 2026-11-17) : scénario a242 du harnais a191 (copie a242) :
# réserve hors de UI_Displayed (Config/Displayed.ShowReserve = false), flèche CloseArrowButton, lignes gardées quand rien ne
# change ; puis le contrat UI (ClaimAllButton sorti, CloseArrowButton facultatif) lu par contrat.luau.
# Arbre sans ShowReserve (avant a242) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   VERBOSE=1 : aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q 'ShowReserve = ' "$ROOT/src/shared/Config/Displayed.luau" 2>/dev/null; then
	echo "banc a242 (réserve hors de l écran, flèche, ClaimAllButton) : SAUTÉ, a242 pas encore fusionné : 0 vérification(s), 0 échec(s)"
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
part "a242" bash "$H/autres-bancs/a191/run.sh" "$ROOT" a242
part "contrat" bash "$H/contrat.sh" "$ROOT"
echo "banc a242 (réserve hors de l écran, flèche, ClaimAllButton) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
