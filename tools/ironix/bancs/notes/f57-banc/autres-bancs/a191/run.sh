#!/usr/bin/env bash
# fusion57 (vague 63) : banc a191 via ../../corrige.sh (lanceur d'avant : a206-banc/autres-bancs/a191/run.sh ; arbre d'avant la vague 63 : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/f57-banc/corrige.sh" a191 "$N/a206-banc/autres-bancs/a191/run.sh" "$@"
