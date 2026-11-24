#!/usr/bin/env bash
# lot98-commun : a183 (copie a262) corrigé par ../../corrige.sh (patches/a183.pl : SelectionGained, a419).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a183 bash "$N/a262-banc/autres-bancs/a183/run.sh" "$@"
