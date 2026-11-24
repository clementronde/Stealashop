#!/usr/bin/env bash
# a299 : banc a209 via ../../corrige.sh (lanceur d'avant : a256-banc/autres-bancs/a209/run.sh ; arbre sans OddBob = 0 : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a299-banc/corrige.sh" a209 "$N/a256-banc/autres-bancs/a209/run.sh" "$@"
