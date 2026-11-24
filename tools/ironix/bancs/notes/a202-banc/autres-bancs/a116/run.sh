#!/usr/bin/env bash
# a202 (vague 62, L-198) : lanceur du banc a116 (a172-banc/autres-bancs/a116/run.sh) sur une copie de l'arbre à Features.SingleBoxReveal = false
# (../../ancien.sh) : le banc ouvre un colis puis prend l'objet sur le rayon (ouverture d'avant). Le nouveau
# déroulé est vérifié par le banc a202. Avant a202 : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/a202-banc/ancien.sh" "$H/a172-banc/autres-bancs/a116/run.sh" repo "${ARG%/src}"
