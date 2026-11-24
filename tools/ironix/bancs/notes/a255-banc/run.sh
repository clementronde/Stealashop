#!/usr/bin/env bash
# Banc hors Studio d a255 (vague 73, L-241 point 4, L-248 ; décision de Cantin du 18/11) : scénario a255 du harnais a191
# (copie a255) : inventaire sous les exposés, toujours montré, ReserveEmpty, InventoryButton de UI_Hotbar et sa pastille
# InventoryAlert, Toggle sur l écran réel ; puis contrat.sh. Arbre sans InventoryAlert (avant a255) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   VERBOSE=1 : aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "InventoryAlert = " "$ROOT/src/shared/Config/Displayed.luau" 2>/dev/null; then
	echo "banc a255 (inventaire, InventoryButton, pastille) : SAUTÉ, a255 pas encore fusionné : 0 vérification(s), 0 échec(s)"
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
part "a255" bash "$H/autres-bancs/a191/run.sh" "$ROOT" a255
part "contrat" bash "$H/contrat.sh" "$ROOT"
echo "banc a255 (inventaire, InventoryButton, pastille) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
