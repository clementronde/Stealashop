#!/usr/bin/env bash
# lot98-commun : a59 de pc3-lot98-bancs (a401 coupé, faux GetScale et ScaleTo pour a418) corrigé par ../../corrige.sh
# (patches/a59.pl : PivotOffset mis à l'échelle dans le faux ScaleTo ; attentes d'a418 et d'a317, L-304).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a59 bash "$N/pc3-lot98-bancs/a59/run.sh" "$@"
