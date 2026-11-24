#!/usr/bin/env bash
# Banc a289 (Cantin, 21/11 : « elle disparaît quand le vol est fini cad quand l'item est ramené ») :
#   crowd    WitnessCrowdController, Crowd.Trigger "Enter" : la foule se forme à l'entrée (a288), reste tant qu'un
#            voleur de ce magasin porte (attribut Carrying du Player), part à la fin du vol (dépôt, capture, perte,
#            vol par un autre, départ du jeu), Duration s après la sortie sans vol, MaxStay 300 s en filet ; reprend
#            le banc a288 (E0 à E10, adapté) ; et "Exit" (l'ancien moment) ; faux Roblox du banc a240 crowd
# « SAUTÉ » sur un arbre sans la fin au vol (avant a289). Remplace le banc a288 dans le lanceur.
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
NAME="banc a289 (foule jusqu'à la fin du vol)"
out=$(timeout 300 bash "$H/crowd-run.sh" "$ROOT" 2>&1)
if printf '%s\n' "$out" | grep -q "SAUTÉ"; then echo "$NAME : SAUTÉ, 0 vérification(s), 0 échec(s)"; exit 0; fi
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|MESURE" | sed "s/^/  crowd /"
line=$(printf '%s\n' "$out" | grep -E "^banc a289 crowd : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "$NAME : 0 vérification(s), 1 échec(s)"; exit 1; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$NAME : $c vérification(s), $f échec(s)"
exit $((f > 0))
