#!/usr/bin/env bash
# a226 (vague 68) : lanceur du banc a210 (a210-banc/run.sh) sur une copie de l'arbre remise comme avant a226 (../../avant.sh) :
# le banc écrit en dur les prix des auras (500 $ à 8 B). Arbre sans a226 : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a226-banc/avant.sh" "$H/a210-banc/run.sh" "${1:-/f/StealAShop}"
