#!/usr/bin/env bash
# a266 (vague 80) : banc a154 tel que le lance le lanceur commun (a262-banc/autres-bancs/a154), corrigé par a266-banc/corrige.sh (patches/a154.pl : I0b).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a266-banc/corrige.sh" a154 "$N/a262-banc/autres-bancs/a154/run.sh" "$@"
