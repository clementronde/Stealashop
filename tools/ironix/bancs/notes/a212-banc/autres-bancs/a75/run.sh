#!/usr/bin/env bash
# a212 (vague 64) : banc a75 via ../../corrige.sh (lanceur d avant : f53-banc/autres-bancs/a75/run.sh ; arbre sans VideoRhythm : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a212-banc/corrige.sh" a75 "$N/f53-banc/autres-bancs/a75/run.sh" "$@"
