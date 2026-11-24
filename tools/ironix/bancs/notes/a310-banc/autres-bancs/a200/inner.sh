#!/usr/bin/env bash
# a310 : étape a213 de la chaîne (vol des gains du tapis coupé), comme a213-banc/autres-bancs/a200/run.sh.
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a213-banc/corrige.sh" a200 "$N/a310-banc/autres-bancs/a200/banc.sh" "$@"
