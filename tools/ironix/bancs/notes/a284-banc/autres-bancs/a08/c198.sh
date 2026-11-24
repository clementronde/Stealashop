#!/usr/bin/env bash
# a284 : comme a198-banc/autres-bancs/a08/run.sh, vers la copie a284 (run.sh à côté).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/a198-banc/echelle1.sh" "$H/a284-banc/autres-bancs/a08/run.sh" src "${ARG%/src}"
