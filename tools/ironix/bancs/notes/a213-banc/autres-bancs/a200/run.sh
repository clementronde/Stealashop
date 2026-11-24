#!/usr/bin/env bash
# a213 (vague 64) : banc a200 via ../../corrige.sh, vol des gains du tapis coupé (lanceur d'avant : a200-banc/run.sh ; arbre sans TrainGainFly : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a213-banc/corrige.sh" a200 "$N/a200-banc/run.sh" "$@"
