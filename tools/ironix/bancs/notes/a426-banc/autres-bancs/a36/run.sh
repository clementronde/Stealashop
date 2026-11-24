#!/usr/bin/env bash
# a426 (24/11, L-319) : banc a36 (lanceur a198-banc/autres-bancs/a36) sur l'arbre à Features.SafeZoneSpeed = false
# (../../regle-coupee.sh) : ses scénarios attendent dans la zone safe de leur faux arbre la vitesse de la formule ou la
# vitesse fixe de l'objet volé (a30 : S7g, vitesse 16 après l'étourdissement ; a36 : S1a, 70, et V2b, 16). La règle de la
# zone safe est vérifiée par le banc a426. Avant a426 : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/a426-banc/regle-coupee.sh" "$H/a198-banc/autres-bancs/a36/run.sh" repo "${ARG%/src}"
