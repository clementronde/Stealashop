#!/usr/bin/env bash
# a180 (2026-11-15, vague 55) : lanceur du banc a65 (a134-banc/autres-bancs/a65/run.sh) sur l'arbre où Training.Treadmill.SideEntryOnly = false
# (ses scénarios posent le joueur droit sur la bande ; ../../regle-coupee.sh). Avant a180 : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/a180-banc/regle-coupee.sh" "$H/a134-banc/autres-bancs/a65/run.sh" repo "${ARG%/src}"
