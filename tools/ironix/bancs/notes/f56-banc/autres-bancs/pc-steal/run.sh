#!/usr/bin/env bash
# fusion56 (vague 62) : banc pc-steal avec a203 (a203-banc/autres-bancs/lanceur.sh : ItemWeight en ligne, poids coupé)
# par-dessus base.sh (liste ScaleTo relue avec RevealController d a204).
exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a203-banc/autres-bancs/lanceur.sh" pc-steal f56-banc/autres-bancs/pc-steal/base.sh "$@"
