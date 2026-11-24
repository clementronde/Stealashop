#!/usr/bin/env bash
# f70c3b : lanceur du banc a224 (a249-banc/autres-bancs/a224/run.sh) sur une copie de l'arbre à
# Chase.ApproachSlowNear = true (f70c3-banc/lent.sh : approche lente vérifiée par a224, scénarios S1 à S4).
S="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$S/f70c3-banc/lent.sh" "$S/a249-banc/autres-bancs/a224/run.sh" "$ARG"
