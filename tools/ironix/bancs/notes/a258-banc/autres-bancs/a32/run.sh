#!/usr/bin/env bash
# a258 (vague 74) : banc a32 via ../../corrige.sh (Config/UiMotion WINDOW_E = false ; son scénario lit la durée d entrée d une seule échelle ; lanceur d avant : a227-banc/autres-bancs/a32/run.sh ; arbre sans WindowE : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a258-banc/corrige.sh" a32 "$N/a227-banc/autres-bancs/a32/run.sh" "$@"
