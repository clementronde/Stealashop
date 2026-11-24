#!/usr/bin/env bash
# a212 (vague 64) : banc a37 via ../../corrige.sh (lanceur d avant : a190-banc/autres-bancs/a37/run.sh ; arbre sans VideoRhythm : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a212-banc/corrige.sh" a37 "$N/a190-banc/autres-bancs/a37/run.sh" "$@"
