#!/usr/bin/env bash
# a249 : prend le verrou commun des bancs (mkdir F:/StealAShop/.verrou-bancs ; attend s'il est pris), lance la commande, rend le verrou.
set -u
L=/f/StealAShop/.verrou-bancs
until mkdir "$L" 2>/dev/null; do echo "verrou pris, attente…"; sleep 20; done
trap 'rmdir "$L"' EXIT
echo "verrou pris par a249 : $(date +%T)"
"$@"
