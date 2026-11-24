#!/usr/bin/env bash
# a249 (poursuite phase 2, L-235) : lanceur du banc a224 (a232-banc/autres-bancs/a224/run.sh) sur une copie de l'arbre aux interrupteurs a249 coupés
# (a249-banc/avant.sh : ruée, départ à 0,5 s, reprise immédiate, double capture, zone 1 sans minimum) ; les nouvelles
# règles sont vérifiées par le banc a249. Arbre sans a249 : le lanceur d'avant tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$S/a249-banc/avant.sh" "$S/a232-banc/autres-bancs/a224/run.sh" "$ARG"
