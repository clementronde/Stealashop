#!/usr/bin/env bash
# Banc hors Studio d a240 (vague 72 : la foule sans à-coup et ses sons, L-229) :
#   crowd    WitnessCrowdController : création étalée (BuildPerFrame), cris au marqueur Shout, photos au flash, Gasp à la
#            casse, plafonds de voix, son absent muet (faux Roblox du banc a236 crowd, copie a240)
# « SAUTÉ » sur un arbre sans a240. Le banc a236 passe par autres-bancs/a236 (heist attend la foule complète).
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
out=$(timeout 300 bash "$H/crowd/run.sh" "$ROOT" 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ|MESURE" | sed "s/^/  crowd /"
line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "banc a240 (foule étalée, sons) : 0 vérification(s), 1 échec(s)"; exit 1; fi
c=$(printf '%s' "$line" | sed -E 's/.*: ([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a240 (foule étalée, sons) : $c vérification(s), $f échec(s)"
exit $((f > 0))
