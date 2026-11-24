#!/usr/bin/env bash
# a262 (corrections de Cantin du 20/11) : le lanceur d avant (a226-banc/run.sh) sur l arbre remis comme avant ces corrections (../../avant-cantin.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a262-banc/avant-cantin.sh" "$H/a226-banc/run.sh" "$1"
