#!/usr/bin/env bash
# a212 (vague 64) : banc a209 via ../../corrige.sh (lanceur d avant : f57-banc/autres-bancs/a209/run.sh ; arbre sans VideoRhythm : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a212-banc/corrige.sh" a209 "$N/f57-banc/autres-bancs/a209/run.sh" "$@"
