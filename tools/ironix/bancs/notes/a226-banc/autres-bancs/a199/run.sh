#!/usr/bin/env bash
# a226 (vague 68) : lanceur du banc a199 (a199-banc/run.sh) sur une copie de l'arbre remise comme avant a226 (../../avant.sh) :
# le banc écrit en dur un premier achat d'aura à 500 $ (dons du tuto : la logique ne change pas, seul le prix). Arbre sans a226 : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a226-banc/avant.sh" "$H/a199-banc/run.sh" "${1:-/f/StealAShop}"
