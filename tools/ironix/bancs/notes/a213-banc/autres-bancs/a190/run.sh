#!/usr/bin/env bash
# a213 (vague 64) : banc a190 via ../../corrige.sh, vol des gains du tapis coupé (lanceur d'avant : a205-banc/autres-bancs/a190/run.sh ; arbre sans TrainGainFly : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a213-banc/corrige.sh" a190 "$N/a205-banc/autres-bancs/a190/run.sh" "$@"
