#!/usr/bin/env bash
# a226 (vague 68) : lanceur du banc a198 (a198-banc/run.sh) sur une copie de l'arbre remise comme avant a226 (../../avant.sh) :
# le banc écrit en dur les PV des vitrines des zones 3 à 5. Arbre sans a226 : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a226-banc/avant.sh" "$H/a198-banc/run.sh" "${1:-/f/StealAShop}"
