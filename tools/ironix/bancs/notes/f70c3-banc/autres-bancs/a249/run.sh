#!/usr/bin/env bash
# f70c3b : lanceur du banc a249 (a250-banc/autres-bancs/a249/run.sh) sur une copie de l'arbre à
# Chase.ApproachSlowNear = true (f70c3-banc/lent.sh : le scénario coince, Ka, attend la prise lente d'un voleur
# arrêté). Le voleur arrêté sans ralentissement est vérifié par le banc f70c3 (scénario proche).
S="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
shift || true
exec bash "$S/f70c3-banc/lent.sh" "$S/a250-banc/autres-bancs/a249/run.sh" "$ARG" "$@"
