#!/usr/bin/env bash
# a256 (vague 73) : banc a28 via ../../corrige.sh (lanceur d avant : a226-banc/autres-bancs/a28/run.sh ; arbre sans WindowTas : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a256-banc/corrige.sh" a28 "$N/a226-banc/autres-bancs/a28/run.sh" "$@"
