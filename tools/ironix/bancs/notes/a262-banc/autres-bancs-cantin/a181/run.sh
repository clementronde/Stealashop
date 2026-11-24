#!/usr/bin/env bash
# a262 (corrections de Cantin du 20/11) : le lanceur d avant (f62-banc/autres-bancs/a181/run.sh) sur l arbre remis comme avant ces corrections (../../avant-cantin.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a262-banc/avant-cantin.sh" "$H/f62-banc/autres-bancs/a181/run.sh" "$1"
