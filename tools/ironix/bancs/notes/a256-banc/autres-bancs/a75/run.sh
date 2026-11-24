#!/usr/bin/env bash
# a256 (vague 73) : banc a75 via ../../corrige.sh (lanceur d avant : a230-banc/autres-bancs/a75/run.sh ; arbre sans WindowTas : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a256-banc/corrige.sh" a75 "$N/a230-banc/autres-bancs/a75/run.sh" "$@"
