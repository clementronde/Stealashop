#!/usr/bin/env bash
# lot96 : a154 (copie a266) corrigé par ../../corrige.sh (patches/a154.pl : remotes d a314 et a410 après ItemSecured).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot96-banc/corrige.sh" a154 bash "$N/a266-banc/autres-bancs/a154/run.sh" "$@"
