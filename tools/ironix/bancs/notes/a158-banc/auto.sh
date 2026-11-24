#!/usr/bin/env bash
# a158, outil de travail : lance un banc par son lanceur (lanceur2.sh) et résume, scénario par scénario :
#   bash auto.sh <nom>            état de chaque scénario, libellés des échecs (courts), erreurs
#   bash auto.sh <nom> garde      écrit dans origines2.txt la liste des scénarios sans échec (ou RETIRE s'il n'en reste aucun)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"
out="$(FULL=1 bash "$H/lanceur.sh" "$NAME" 2>&1)"
good="$(printf '%s\n' "$out" | sed -nE 's/^ +([A-Za-z0-9_.-]+) : [0-9]+ contrôles, 0 raté\(s\)$/\1/p' | tr '\n' ' ')"
bad="$(printf '%s\n' "$out" | sed -nE 's/^ +([A-Za-z0-9_.-]+) : [0-9]+ contrôles, [1-9][0-9]* raté\(s\)$/\1/p; s/^scénario ([A-Za-z0-9_.-]+) : arrêté avant.*/\1/p' | tr '\n' ' ')"
echo "$NAME | bons : $good| mauvais : $bad"
printf '%s\n' "$out" | grep -E "ÉCHEC|luau:[0-9]+: " | sed -E 's#C:/Users[^ ]*/(run[^/ ]*luau)#\1#; s/^ +//' | cut -c1-${WIDTH:-120} | head -${LINES_MAX:-14}
printf '%s\n' "$out" | grep -E "vérification\(s\)|réussi\(s\)" | tail -1 | cut -c1-120
if [ "${2:-}" = "garde" ]; then
	if [ -n "$good" ]; then
		bash "$H/scen.sh" "$NAME" $good
	else
		echo "aucun scénario sans échec : à retirer à la main (scen.sh $NAME RETIRE raison)"
	fi
fi
