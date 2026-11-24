#!/usr/bin/env bash
# a198 (vague 61) : lanceur du banc a168 (a174-banc/autres-bancs/a168/lanceur.sh) sur une copie de l'arbre remise comme avant a198 (vitesse réelle
# à l'échelle 1, zone 1 sans WindowHP = 15 ; ../../echelle1.sh) : le banc écrit en dur des vitesses ou des durées à
# l'échelle 1. Avant a198 : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/a198-banc/echelle1.sh" "$H/a174-banc/autres-bancs/a168/lanceur.sh" repo "${ARG%/src}"
