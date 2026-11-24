#!/usr/bin/env bash
# fusion58 (vague 64) : banc a81 via a213-banc/corrige.sh, vol des gains du tapis coupé (son faux Roblox ne simule pas Quint ; lanceur d'avant : a86-banc/autres-bancs/a81-banc/run.sh ; arbre sans TrainGainFly : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a213-banc/corrige.sh" a81 "$N/a86-banc/autres-bancs/a81-banc/run.sh" "$@"
