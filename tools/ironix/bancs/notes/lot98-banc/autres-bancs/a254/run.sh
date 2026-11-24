#!/usr/bin/env bash
# lot98-commun : a254 (copie a262) corrigé par ../../corrige.sh (patches/a254.pl : Notify en file au texte d'a412).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a254 bash "$N/a262-banc/autres-bancs/a254/run.sh" "$@"
