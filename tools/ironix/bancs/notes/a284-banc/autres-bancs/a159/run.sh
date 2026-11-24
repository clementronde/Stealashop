#!/usr/bin/env bash
# a284 : le lanceur du banc a159 d'avant (a183-banc/autres-bancs/a159/run.sh) sur l'arbre à RegenSyncHz = 10
# (../../regen10.sh) : il mesure la réparation de la porte sur les PV reçus au dixième de seconde.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a284-banc/regen10.sh" "$H/a183-banc/autres-bancs/a159/run.sh" "${1:-/f/StealAShop}"
