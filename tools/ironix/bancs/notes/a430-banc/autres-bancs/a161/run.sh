#!/usr/bin/env bash
# a430 (L-330) : banc a161 du lanceur commun (a262-banc/autres-bancs/a161/run.sh), avec le faux Inst.IsDescendantOf
# (../../corrige.sh, descendant.pl). Arbre sans le filtre du Workspace : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a430-banc/corrige.sh" "$S/a262-banc/autres-bancs/a161/run.sh" "$@"
