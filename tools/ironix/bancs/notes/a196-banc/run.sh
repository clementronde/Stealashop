#!/usr/bin/env bash
# Banc hors Studio d'a196 (vague 60 : T-096 « BEST ITEM », T-097 exposant du trail, T-087 témoin loin et flash) :
#   socle    l'objet exposé au plus gros revenu, « BEST ITEM », revenu/s dans Income ou Odds (harnais a161)
#   trail    « ×2 » en petit TextLabel au coin haut droit du nombre, sans et avec Row.Multiplier (harnais a155 copie a178)
#   witness  vitesse d'approche du témoin selon la distance et le temps restant, plafond (harnais a182 / a100)
#   client   deux émissions par flash, lumière jusqu'à la dernière (harnais a182 client)
# Chaque partie dit « SAUTÉ » sur un arbre sans a196.
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
total=0; failed=0; broken=0
for part in socle trail witness client; do
	out=$(timeout 300 bash "$H/$part/run.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" | sed "s/^/  $part /"
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "  $part : arrêté avant la fin"; broken=$((broken + 1)); continue; fi
	c=$(printf '%s' "$line" | sed -E 's/^.*[^0-9]([0-9]+) vérif.*/\1/; s/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $part : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
done
failed=$((failed + broken))
echo "banc a196 (BEST ITEM, exposant, témoin) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
