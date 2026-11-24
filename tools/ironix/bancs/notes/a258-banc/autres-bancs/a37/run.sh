#!/usr/bin/env bash
# a258 (vague 74) : banc a37 via ../../corrige.sh (Config/UiMotion WINDOW_E = false ; ses scénarios lisent l ouverture et la fermeture en un seul tween ; lanceur d avant : a212-banc/autres-bancs/a37/run.sh ; arbre sans WindowE : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a258-banc/corrige.sh" a37 "$N/a212-banc/autres-bancs/a37/run.sh" "$@"
