#!/usr/bin/env bash
# lot98 (petit chef 3) : a226 aux textes d'a412 (a412-banc/autres-bancs/a226) sur l'arbre sans outils de renaissance
# d'a407 (sans-outils.sh).
H="$(cd "$(dirname "$0")/../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/a407-banc/sans-outils.sh" "$H/a412-banc/autres-bancs/a226/run.sh" repo "${ARG%/src}"
