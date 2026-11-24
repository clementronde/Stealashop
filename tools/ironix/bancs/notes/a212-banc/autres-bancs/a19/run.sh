#!/usr/bin/env bash
# a212 (vague 64) : banc a19 via ../../corrige.sh (lanceur d avant : a134-banc/autres-bancs/a19/run.sh ; arbre sans VideoRhythm : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a212-banc/corrige.sh" a19 "$N/a134-banc/autres-bancs/a19/run.sh" "$@"
