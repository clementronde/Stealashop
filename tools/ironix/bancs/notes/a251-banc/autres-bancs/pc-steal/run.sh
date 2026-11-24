#!/usr/bin/env bash
# a251 (vague 73) : banc pc-steal avec a203 (a203-banc/autres-bancs/lanceur.sh) par-dessus a251-banc/autres-bancs/
# pc-steal/base.sh (liste ScaleTo relue avec Reveal/Unbox d'a251).
exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a203-banc/autres-bancs/lanceur.sh" pc-steal a251-banc/autres-bancs/pc-steal/base.sh "$@"
