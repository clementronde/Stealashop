#!/usr/bin/env bash
# a213 (vague 64) : banc a60 via ../../corrige.sh, vol des gains du tapis coupé (lanceur d'avant : a192-banc/autres-bancs/a60/run.sh ; arbre sans TrainGainFly : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a213-banc/corrige.sh" a60 "$N/a192-banc/autres-bancs/a60/run.sh" "$@"
