#!/usr/bin/env bash
# Banc hors Studio d'a182 (2026-11-15, vague 56, L-172 : le témoin qui filme la casse ; Witness.Photo) :
#   witness  approche du poste devant la vitre, appel, photos au flash (marqueur Flash, cadence 0,9 s, jamais deux à
#            moins de 0,45 s), sans TakePhoto, arrêts (policier arrivé, police repartie, voleur parti, zone safe,
#            MaxTime), fuite des autres à la casse (vrai WitnessService, harnais a100 copie a151)
#   client   flash de FX_Witness_Flash dans WitnessController (faux Roblox minimal)
# Chaque partie dit « SAUTÉ » sur un arbre sans Witness.Photo.
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
total=0; failed=0; broken=0
for part in witness client; do
	out=$(timeout 300 bash "$H/$part/run.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" | sed "s/^/  $part /"
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then echo "  $part : arrêté avant la fin"; broken=$((broken + 1)); continue; fi
	c=$(printf '%s' "$line" | sed -E 's/^.*[^0-9]([0-9]+) vérif.*/\1/; s/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $part : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
done
failed=$((failed + broken))
echo "banc a182 (témoin qui filme) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
