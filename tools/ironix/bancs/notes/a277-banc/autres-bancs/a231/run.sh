#!/usr/bin/env bash
# a277 : copie de la copie a252 ; partie checker : Sprint (a277, L-249) admise en 7e animation des vigiles de magasin, après PickUp.
# a252 : copie du banc a231 (partie poids lue sur place) ; partie checker : tests.luau d a231 avec PickUp (a252) admis
# en 6e animation des vigiles de magasin (Animations.Guard), les vigiles de nuit inchangés.
# Banc a231 (vague 70) : poids/ (vieux profil : Tiny et Big retirées de la mutation, poids et revenu inchangés) et
# checker/ (vrai ContractChecker sur 12 faux NPC_Crowd, Animations.Crowd de L-223). Le journal de capture du vigile
# (« l'objet de X ») est vérifié dans autres-bancs/a174 et a172. Chaque partie dit « SAUTÉ » avant la fusion d'a231.
H="$(cd "$(dirname "$0")" && pwd)"
ARG="${1:-/f/StealAShop}"
total=0
failed=0
for part in poids checker; do
	if [ "$part" = poids ]; then out=$(bash "/c/Users/user/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_8069c51a-7fa2-4234-b865-b99cadfc62e3/a231-banc/poids/run.sh" "$ARG" 2>&1); else out=$(bash "$H/$part/run.sh" "$ARG" 2>&1); fi
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
