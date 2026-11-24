#!/usr/bin/env bash
# Banc a297 (21/11, correctifs de la caisse exclusive, validés par le grand chef) : serveur seulement (inner.sh, mise en
# place du banc a38 sous a158-banc/corrige.sh, comme a294).
#   msg   messages « you got … » : avec une ouverture, aucun avant la fin ; à la fin (RevealDone, plafond, mort, nouvelle
#         caisse), ceux des seuls objets non montrés (0 pour Crate1, 2 pour Crate3), au même instant que RevealEnded ;
#         départ : aucun ; hors zone safe et ouverture coupée : tous tout de suite ; le don reste immédiat
#   off   Crate.Reveal.Enabled = false : tous les messages tout de suite
#   hook  crochet MonetizationTest : reçus « STUDIO-<GUID du Play>-n », deux Play simulés (BancNewPlay) avec le même
#         profil donnent des reçus différents, le 1er essai du 2e Play est donné ; un même reçu rejoué : rien de plus
# Arbre sans a297 (pas de testSession dans MonetizationService) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]     PARTS="msg" : scénarios choisis ; VERBOSE=1 : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
LABEL="banc a297 (caisse exclusive : messages à la fin de l'ouverture, reçus de test uniques)"
if ! grep -q 'local testSession: string? = nil' "$ROOT/src/server/Services/MonetizationService.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, pas de testSession dans $ROOT : 0 vérification(s), 0 échec(s)"
	exit 0
fi
out=$(bash "$H/../a158-banc/corrige.sh" a38 bash "$H/inner.sh" "$ROOT" 2>&1)
printf '%s\n' "$out" | grep -v -E "^banc a297 serveur : " || true
line=$(printf '%s\n' "$out" | grep -E "^banc a297 serveur : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	echo "$LABEL : arrêté avant la fin"
	exit 1
fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$LABEL : $c vérification(s), $f échec(s)"
exit $((f > 0))
