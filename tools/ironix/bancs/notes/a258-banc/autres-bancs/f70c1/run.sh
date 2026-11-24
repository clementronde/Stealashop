#!/usr/bin/env bash
# a258 (vague 74) : banc f70c1 via ../../corrige.sh (Config/UiMotion WINDOW_E = false ; UI_Displayed floute à 16 dans son scénario, L-259 le retire des fenêtres centrales ; lanceur d avant : f70c1-banc/run.sh ; arbre sans WindowE : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a258-banc/corrige.sh" f70c1 "$N/f70c1-banc/run.sh" "$@"
