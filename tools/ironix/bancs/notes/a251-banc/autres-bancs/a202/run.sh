#!/usr/bin/env bash
# a251 (vague 73, L-236) : lanceur du banc a202 (a249-banc/autres-bancs/a202/run.sh) sur une copie de l'arbre où la
# nouvelle ouverture du colis est coupée (a251-banc/avant.sh) : ses plafonds de 8, 10 et 12 s sont ceux de la cinématique
# d'avant ; le plan et le nouveau plafond sont vérifiés par le banc a251 (scénario server). Arbre sans a251 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$S/a251-banc/avant.sh" "$S/a249-banc/autres-bancs/a202/run.sh" "$ARG"
