#!/usr/bin/env bash
# lot98-commun : comme a251-banc/autres-bancs/pc-steal/run.sh (a203 par-dessus), sur la copie base.sh d'ici.
exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a203-banc/autres-bancs/lanceur.sh" pc-steal lot98-banc/autres-bancs/pc-steal/base.sh "$@"
