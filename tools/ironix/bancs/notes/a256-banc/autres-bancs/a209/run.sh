#!/usr/bin/env bash
# a256 (vague 73) : banc a209 via ../../corrige.sh (lanceur d avant : a212-banc/autres-bancs/a209/run.sh ; arbre sans WindowTas : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a256-banc/corrige.sh" a209 "$N/a212-banc/autres-bancs/a209/run.sh" "$@"
