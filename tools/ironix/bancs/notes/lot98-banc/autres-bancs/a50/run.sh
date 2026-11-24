#!/usr/bin/env bash
# lot98-commun : a50 (a50-banc) corrigé par ../../corrige.sh (patches/a50.pl : 9 outils et 6 icônes manquantes, a407).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a50 bash "$N/a50-banc/run.sh" "$@"
