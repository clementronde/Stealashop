#!/usr/bin/env bash
# a224 (vague 67) : banc a168 via ../../corrige-chase.sh, ApproachBrake = 0 (lanceur d'avant : a198-banc/autres-bancs/a168/run.sh ; arbre sans ApproachBrake : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a224-banc/corrige-chase.sh" a168 "$N/a198-banc/autres-bancs/a168/run.sh" "$@"
