#!/usr/bin/env bash
# f70c4 : banc a220 sur un arbre à Config/Reveal.Return.Time = 0 (f70c4-banc/corrige.sh, patches/a220.sed) : ses scénarios
# lisent la caméra, le HUD et les pièces cachées rendus d'un coup à Land. Arbre sans f70c4 : le patch ne change rien.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)"
bash "$N/f70c4-banc/corrige.sh" a220 bash "$N/a220-banc/run.sh" "$@"
