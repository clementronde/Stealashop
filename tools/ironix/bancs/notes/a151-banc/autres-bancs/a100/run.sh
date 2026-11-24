#!/usr/bin/env bash
# Copie a151 (2026-11-14, vague 43, Cantin : un policier par joueur qui a frappé la vitrine, au plus
# Witness.Police.MaxPerStore par magasin) : tests du volet témoins revus (scénarios 5 et 6 : deux frappeurs = deux
# policiers) et scénario 10 ajouté (trois casseurs, plafond, appel suivant, nettoyage, GetPolice). Le volet police
# (vrai GuardService) est celui de la copie a134, inchangé.
# Arbre sans la vague 43 (Witness.Police.MaxPerStore absent) : la copie a134 tourne telle quelle.
_A151_R="${1:-/f/StealAShop}"; _A151_F="$_A151_R/src/shared/Config/Witness.luau"
H="$(cd "$(dirname "$0")" && pwd)"
if ! grep -q "MaxPerStore" "$_A151_F" 2>/dev/null; then exec bash "$H/../../../a134-banc/autres-bancs/a100/run.sh" "$@"; fi
set -u
ROOT="${1:-/f/StealAShop}"
total=0; failed=0; broken=0
for part in witness police; do
	if [ "$part" = "witness" ]; then script="$H/witness/run.sh"; else script="$H/../../../a134-banc/autres-bancs/a100/police/run.sh"; fi
	out=$(timeout 300 bash "$script" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" | sed "s/^/  $part /"
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then echo "  $part : arrêté avant la fin"; printf '%s\n' "$out" | tail -8 | sed 's/^/    /'; broken=$((broken + 1)); continue; fi
	c=$(printf '%s' "$line" | sed -E 's/^.*[^0-9]([0-9]+) vérif.*/\1/; s/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $part : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
done
failed=$((failed + broken))
echo "banc a100 (témoins et police) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
