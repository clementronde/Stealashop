#!/usr/bin/env bash
# a230 (vague 70) : banc a75 via ../../corrige.sh (lanceur d avant : a212-banc/autres-bancs/a75/run.sh ; arbre sans HeldIncomeController : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a230-banc/corrige.sh" a75 "$N/a212-banc/autres-bancs/a75/run.sh" "$@"
