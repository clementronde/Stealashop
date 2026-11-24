#!/usr/bin/env bash
# a258 (vague 74) : banc a256 via ../../corrige.sh (Config/UiMotion WINDOW_E = false : ouverture 0,84, flou 16 sur toutes les grandes fenêtres ; arbre sans WindowE : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a258-banc/corrige.sh" a256 "$N/a256-banc/run.sh" "$@"
