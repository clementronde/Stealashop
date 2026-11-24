#!/usr/bin/env bash
# lot98-commun : comme a264-banc/autres-bancs/pc-steal/run.sh, sur l262.sh d'ici.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a264-banc/corrige.sh" "pc-steal" "$S/lot98-banc/autres-bancs/pc-steal/l262.sh" "$@"
