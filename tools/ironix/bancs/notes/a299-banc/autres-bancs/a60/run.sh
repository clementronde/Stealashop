#!/usr/bin/env bash
# a299 : banc a60 via ../../corrige.sh (lanceur d'avant : a291-banc/autres-bancs/a60/run.sh ; arbre sans OddBob = 0 : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a299-banc/corrige.sh" a60 "$N/a291-banc/autres-bancs/a60/run.sh" "$@"
