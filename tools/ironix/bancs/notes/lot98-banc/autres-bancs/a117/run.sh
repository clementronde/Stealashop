#!/usr/bin/env bash
# lot98-commun : a117 (copie a237) corrigé par ../../corrige.sh (patches/a117.pl : bandeau de zone en « Strength », a412).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a117 bash "$N/a237-banc/autres-bancs/a117/run.sh" "$@"
