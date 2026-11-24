#!/usr/bin/env bash
# a213 (vague 64) : banc a62 via ../../corrige.sh, vol des gains du tapis coupé (lanceur d'avant : a190-banc/autres-bancs/a62/run.sh ; arbre sans TrainGainFly : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a213-banc/corrige.sh" a62 "$N/a190-banc/autres-bancs/a62/run.sh" "$@"
