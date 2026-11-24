#!/usr/bin/env bash
# Copie a236 (vague 71 : la partie crowd est remplacée par le banc a236 crowd, foule de L-223) du banc a221 (vague 66, L-210 point 4 : le témoin fonce et photographie dès son arrivée, la foule qui filme) :
#   witness  Photo.Rush : course à RushSpeed (Flee, sinon Walk), photos et flash à son poste pendant que le « ? » monte,
#            fuite à la casse, appel puis photos d'L-172, plafond de vitesse (vrai WitnessService, harnais a100 copie a151)
#   crowd    WitnessCrowdController : foule à la sortie du magasin avec l'objet, arc, sol, regard, rôles, flashs, fondus,
#            fin, refus (Cooldown, caméra, MaxCrowds, aucun témoin), animations réduites, interrupteur (faux Roblox à lui)
# Chaque partie dit « SAUTÉ » sur un arbre sans a221.
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")/../../../a221-banc" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
total=0; failed=0; broken=0
for part in witness; do
	out=$(timeout 300 bash "$H/$part/run.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" | sed "s/^/  $part /"
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "  $part : arrêté avant la fin"; broken=$((broken + 1)); continue; fi
	c=$(printf '%s' "$line" | sed -E 's/^.*[^0-9]([0-9]+) vérif.*/\1/; s/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $part : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
done
failed=$((failed + broken))
echo "banc a221 (témoin qui fonce, foule qui filme) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
