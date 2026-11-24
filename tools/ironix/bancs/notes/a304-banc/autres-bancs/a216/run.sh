#!/usr/bin/env bash
# a304 : banc a216 via ../../corrige.sh (lanceur d'avant : a262-banc/autres-bancs/a216/run.sh ; arbre sans le pop immédiat : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a304-banc/corrige.sh" a216 "$N/a262-banc/autres-bancs/a216/run.sh" "$@"
