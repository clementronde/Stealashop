#!/usr/bin/env bash
# fusion57 (vague 63) : banc a209 via ../../corrige.sh (lanceur d'avant : a209-banc/run.sh ; arbre d'avant la vague 63 : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/f57-banc/corrige.sh" a209 "$N/a209-banc/run.sh" "$@"
