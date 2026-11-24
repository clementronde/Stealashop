#!/usr/bin/env bash
# a224 (vague 67) : banc a215 via ../../corrige.sh, textes et taille d'avant la vague 67 (lanceur d'avant : a215-banc/run.sh ; arbre sans TrainGainFly.Scale : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a224-banc/corrige.sh" a215 "$N/a215-banc/run.sh" "$@"
