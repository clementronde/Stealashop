#!/usr/bin/env bash
# lot98-commun : a129 de pc3-lot98-bancs/scale (faux GetScale et ScaleTo pour a418, a401 coupé) corrigé par ../../corrige.sh
# (patches/a129.pl : PivotOffset mis à l'échelle dans le faux ScaleTo ; attentes d'a418 et d'a317, L-304).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a129 bash "$N/pc3-lot98-bancs/scale/a129/run.sh" "$@"
