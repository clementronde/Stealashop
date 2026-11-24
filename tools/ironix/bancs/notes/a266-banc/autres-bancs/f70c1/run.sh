#!/usr/bin/env bash
# a266 (vague 80) : banc f70c1 tel que le lance le lanceur commun (a258-banc/autres-bancs/f70c1), corrigé par a266-banc/corrige.sh (patches/f70c1.pl : V2, 17 fenêtres).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a266-banc/corrige.sh" f70c1 "$N/a258-banc/autres-bancs/f70c1/run.sh" "$@"
