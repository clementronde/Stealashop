#!/usr/bin/env bash
# a226 (vague 68) : lanceur du banc a134 (f56-banc/autres-bancs/a134/run.sh) sur une copie de l'arbre remise comme avant a226 (../../avant.sh) :
# le banc écrit en dur les dégâts du panneau, les PV des vitrines, des portes et du camion, et les prix ; les nouveaux sont vérifiés par le banc a226. Arbre sans a226 : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a226-banc/avant.sh" "$H/f56-banc/autres-bancs/a134/run.sh" "${1:-/f/StealAShop}"
