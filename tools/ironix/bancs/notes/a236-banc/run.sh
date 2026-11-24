#!/usr/bin/env bash
# Banc hors Studio d'a236 (vague 71, L-219 point 1, L-220 point 2, L-223 : la foule qui regarde le braquage) :
#   crowd    WitnessCrowdController : personnes NPC_Crowd_* de Clément, rôles et accessoires, deux côtés du passage,
#            plus serrés en s'éloignant, aucune collision, nuit, appareil faible, repli sur les témoins (faux Roblox à lui)
# « SAUTÉ » sur un arbre sans a236. Le banc a221 passe par autres-bancs/a221 (sa partie crowd est remplacée par celle-ci).
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
out=$(timeout 300 bash "$H/crowd/run.sh" "$ROOT" 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" | sed "s/^/  crowd /"
line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "banc a236 (foule de L-223) : 0 vérification(s), 1 échec(s)"; exit 1; fi
c=$(printf '%s' "$line" | sed -E 's/.*: ([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a236 (foule de L-223) : $c vérification(s), $f échec(s)"
exit $((f > 0))
