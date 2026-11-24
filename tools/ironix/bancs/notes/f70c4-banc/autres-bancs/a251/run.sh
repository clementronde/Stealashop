#!/usr/bin/env bash
# f70c4 : banc a251 sur un arbre à Config/Reveal.Return.Time = 0 (f70c4-banc/corrige.sh, patches/a251.sed) : ses scénarios
# lisent la caméra, le HUD et les pièces cachées rendus d'un coup à Land. Arbre sans f70c4 : le patch ne change rien.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)"
bash "$N/f70c4-banc/corrige.sh" a251 bash "$N/a251-banc/run.sh" "$@"
