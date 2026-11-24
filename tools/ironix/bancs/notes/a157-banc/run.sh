#!/usr/bin/env bash
# Banc hors Studio d'a157 (2026-11-14, vague 49, Cantin : en zone safe, plus aucun événement des magasins PNJ ;
# Shared/SafeZone) :
#   window   chrono de police : coup sur une vitrine PNJ refusé depuis la zone safe, chrono masqué à l'abri, sans
#            « too slow », l'autre frappeur garde le sien (vrai WindowService, faux Roblox d'a16 copie a44)
#   heist    chrono HEIST masqué à l'abri, jamais montré à un joueur à l'abri ; vigile en attente qui abandonne
#            (vrais StoreHeistService et GuardService, faux Roblox d'a110 copie a134)
#   witness  « ? » qui se vide, appel coupé, police et Notify seulement pour les suspects dehors (harnais a100)
# « SAUTÉ » sur un arbre sans Shared/SafeZone.
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
total=0; failed=0; broken=0
for part in window heist witness; do
	out=$(timeout 300 bash "$H/$part/run.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" | sed "s/^/  $part /"
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then echo "  $part : arrêté avant la fin"; broken=$((broken + 1)); continue; fi
	c=$(printf '%s' "$line" | sed -E 's/^.*[^0-9]([0-9]+) vérif.*/\1/; s/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $part : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
done
failed=$((failed + broken))
echo "banc a157 (zone safe) : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
