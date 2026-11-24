#!/usr/bin/env bash
# f70c4 : banc a204 sur un arbre à Config/Reveal.Return.Time = 0 (f70c4-banc/corrige.sh, patches/a204.sed) : ses scénarios
# lisent la caméra, le HUD et les pièces cachées rendus d'un coup à Land. Arbre sans f70c4 : le patch ne change rien.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)"
bash "$N/f70c4-banc/corrige.sh" a204 bash "$N/a246-banc/autres-bancs/a204/run.sh" "$@"
