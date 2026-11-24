#!/usr/bin/env bash
# lot98-commun : a234 (copie a418) corrigé par ../../corrige.sh (patches/a234.pl : réduction calculée sur fitBox, FitSize
# moins la marge du flottement, a317).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a234 bash "$N/a418-banc/autres-bancs/a234/run.sh" "$@"
