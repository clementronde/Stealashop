#!/usr/bin/env bash
# a251 : attend le verrou commun des bancs au plus $1 secondes (défaut 540) et le prend (mkdir F:/StealAShop/.verrou-bancs).
# Sortie 0 : pris (à rendre par rmdir après la passe) ; 1 : toujours occupé, rien pris. Le script finit de lui-même :
# aucun processus ne reste à attendre le verrou si l'outil qui l'a lancé s'arrête.
set -u
L=/f/StealAShop/.verrou-bancs
LIMIT="${1:-540}"
START=$(date +%s)
until mkdir "$L" 2>/dev/null; do
	if [ $(( $(date +%s) - START )) -ge "$LIMIT" ]; then
		echo "verrou toujours occupé après $LIMIT s : $(date +%T)"
		exit 1
	fi
	sleep 10
done
echo "verrou pris par a251 : $(date +%T)"
