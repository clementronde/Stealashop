#!/usr/bin/env bash
# a213 (vague 64) : banc a155 via ../../corrige.sh, vol des gains du tapis coupé (lanceur d'avant : a198-banc/autres-bancs/a155/run.sh ; arbre sans TrainGainFly : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a213-banc/corrige.sh" a155 "$N/a198-banc/autres-bancs/a155/run.sh" "$@"
