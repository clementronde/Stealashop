#!/usr/bin/env bash
# lot98-commun : a186 (copie a218) corrigé par ../../corrige.sh (patches/a186.pl : palier borné à Divine pour BatteringRam, a407).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a186 bash "$N/a218-banc/autres-bancs/a186/run.sh" "$@"
