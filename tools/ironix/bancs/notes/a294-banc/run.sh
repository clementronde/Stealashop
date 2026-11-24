#!/usr/bin/env bash
# Banc a294 (21/11, Cantin, L-276) : caisse exclusive, chances validées, Disco Ball Épique, allumée en DEV seulement,
# ouverture des colis réutilisée.
#   serveur (inner.sh, mise en place du banc a38 sous a158-banc/corrige.sh, comme a285) :
#     draw    chances (total 100, jamais sous Épique), 100 000 tirages du serveur à ±0,5 point, caisse coupée hors DEV
#     dev     jeu DEV : caisse allumée et vendue boutique coupée (ProcessReceipt des seuls lots), reçus idempotents
#     prod    jeu PROD : caisse coupée (RobuxCrateDev ne compte pas), aucun ProcessReceipt
#     reveal  RevealStarted d'un objet exclusif (plan : coups et cote selon la rareté), acheteur protégé et immobilisé
#             jusqu'à son RevealDone, plafond, mort, départ, lot (le plus rare), hors zone safe
#   client (client.sh, mise en place du banc a287 sous f70c4-banc/corrige.sh a251) : RevealController + Reveal/Unbox
#     jouent l'ouverture de chaque objet exclusif devant l'acheteur, jusqu'au RevealDone
# Arbre sans a294 (pas de Features.RobuxCrateDev) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]     PARTS="draw dev" : scénarios serveur choisis ; VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
LABEL="banc a294 (caisse exclusive : chances, DEV seulement, ouverture)"
if ! grep -q 'RobuxCrateDev = ' "$ROOT/src/shared/Config/Features.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, pas de Features.RobuxCrateDev dans $ROOT : 0 vérification(s), 0 échec(s)"
	exit 0
fi
total=0
fails=0
for step in serveur client; do
	if [ "$step" = serveur ]; then
		out=$(bash "$H/../a158-banc/corrige.sh" a38 bash "$H/inner.sh" "$ROOT" 2>&1)
	else
		out=$(bash "$H/../f70c4-banc/corrige.sh" a251 bash "$H/client.sh" "$ROOT" 2>&1)
	fi
	printf '%s\n' "$out" | grep -v -E "^banc a294 (serveur|client) : " || true
	line=$(printf '%s\n' "$out" | grep -E "^banc a294 $step : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		echo "$LABEL $step : arrêté avant la fin"
		fails=$((fails + 1))
		continue
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c))
	fails=$((fails + f))
done
echo "$LABEL : $total vérification(s), $fails échec(s)"
exit $((fails > 0))
