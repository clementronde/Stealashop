#!/usr/bin/env bash
# fusion57 (vague 63) : banc a171 via ../../corrige.sh (lanceur d'avant : a203-banc/autres-bancs/a171/run.sh ; arbre d'avant la vague 63 : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/f57-banc/corrige.sh" a171 "$N/a203-banc/autres-bancs/a171/run.sh" "$@"
