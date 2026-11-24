#!/usr/bin/env bash
# lot98-commun : a238 (copie a262) corrigé par ../../corrige.sh (patches/a238.pl : ShopBoosts sans SpeedBoost, a319).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a238 bash "$N/a262-banc/autres-bancs/a238/run.sh" "$@"
