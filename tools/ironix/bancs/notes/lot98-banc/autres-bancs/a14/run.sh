#!/usr/bin/env bash
# lot98-commun : a14 de pc3-lot98-bancs (a401 coupé, faux GetScale et ScaleTo pour a418) corrigé par ../../corrige.sh
# (patches/a14.pl : PivotOffset mis à l'échelle dans le faux ScaleTo ; attentes d'a418 et d'a317, L-304).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a14 bash "$N/pc3-lot98-bancs/a14/run.sh" "$@"
