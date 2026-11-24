#!/usr/bin/env bash
# a212 (vague 64) : banc a189 via ../../corrige.sh (lanceur d avant : a189-banc/run.sh ; arbre sans VideoRhythm : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a212-banc/corrige.sh" a189 "$N/a189-banc/run.sh" "$@"
