#!/usr/bin/env bash
# a308 : banc a60 via ../../corrige.sh (lanceur d'avant : a299-banc/autres-bancs/a60/run.sh ; arbre sans FillParentScreens : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a308-banc/corrige.sh" a60 "$N/a299-banc/autres-bancs/a60/run.sh" "$@"
