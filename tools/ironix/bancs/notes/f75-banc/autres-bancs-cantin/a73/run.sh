#!/usr/bin/env bash
# f75 (corrections de Cantin du 20/11, oublié par a262) : le lanceur d avant (f62-banc/autres-bancs/a73/run.sh) sur l arbre remis comme avant ces corrections (a262-banc/avant-cantin.sh ; sans ShelfStepUp : le lanceur d avant tel quel).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a262-banc/avant-cantin.sh" "$H/f62-banc/autres-bancs/a73/run.sh" "$1"
