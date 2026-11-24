#!/usr/bin/env bash
# Banc a231 (vague 70) : poids/ (vieux profil : Tiny et Big retirées de la mutation, poids et revenu inchangés) et
# checker/ (vrai ContractChecker sur 12 faux NPC_Crowd, Animations.Crowd de L-223). Le journal de capture du vigile
# (« l'objet de X ») est vérifié dans autres-bancs/a174 et a172. Chaque partie dit « SAUTÉ » avant la fusion d'a231.
H="$(cd "$(dirname "$0")" && pwd)"
ARG="${1:-/f/StealAShop}"
total=0
failed=0
for part in poids checker; do
	out=$(bash "$H/$part/run.sh" "$ARG" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" | sed "s/^/  [$part] /" || true
	line=$(printf '%s\n' "$out" | grep -E ": [0-9]+ vérification\(s\), [0-9]+ échec\(s\)" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -10
		failed=$((failed + 1))
		continue
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c))
	failed=$((failed + f))
done
echo "banc a231 (vieux profils, foule au contrat) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
