#!/usr/bin/env bash
# a304 : banc a212 via ../../corrige.sh (lanceur d'avant : a256-banc/autres-bancs/a212/run.sh ; arbre sans le pop immédiat : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a304-banc/corrige.sh" a212 "$N/a256-banc/autres-bancs/a212/run.sh" "$@"
