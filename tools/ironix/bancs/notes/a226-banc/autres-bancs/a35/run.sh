#!/usr/bin/env bash
# a226 (vague 68) : lanceur du banc a35 (a158-banc/autres-bancs/a35/run.sh) sur une copie de l'arbre remise comme avant a226 (../../avant.sh) :
# le banc écrit en dur des puissances d'armes, des prix d'auras ou de traînées, des PV de vitrines ou le texte du panneau de la dernière zone ;
# les nouveaux sont vérifiés par le banc a226. Arbre sans a226 : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a226-banc/avant.sh" "$H/a158-banc/autres-bancs/a35/run.sh" "${1:-/f/StealAShop}"
