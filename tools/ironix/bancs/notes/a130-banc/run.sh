#!/usr/bin/env bash
# Banc hors Studio d'a130 (vague 39, 2026-11-14) : suites de la Fortune Tower et vendeurs des comptoirs.
#   admin   : StartEvent Fortune / FortuneOpen / FortuneSeal, Truck refusé pendant une vitrine (harnais du banc a98)
#   fortune : FortuneTowerService.Force, pas de camion tant qu'une vitrine est en jeu (assemblage du banc a123)
#   telem   : BatBoxKnockdown Source Store / Truck / Fortune (mise en place de la copie a126 du banc a35)
#   vendor  : VendorService, Idle et Wave, sans animations rien (faux Roblox à lui)
# Chaque partie dit « SAUTÉ » sur un arbre sans a130.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
checks=0
fails=0
for part in admin fortune telem vendor; do
	out=$(bash "$H/run-$part.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|arrêté|SAUTÉ" || true
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		fails=$((fails + 1))
		continue
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	checks=$((checks + c))
	fails=$((fails + f))
done
echo "banc a130 (Fortune Tower, vendeurs) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))
