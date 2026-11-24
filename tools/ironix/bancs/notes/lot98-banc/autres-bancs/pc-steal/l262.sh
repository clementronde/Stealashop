#!/usr/bin/env bash
# lot98-commun : comme a262-banc/autres-bancs/pc-steal/run.sh, sur l251.sh d'ici.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a262-banc/corrige.sh" "pc-steal" "$S/lot98-banc/autres-bancs/pc-steal/l251.sh" "$@"
