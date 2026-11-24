#!/usr/bin/env bash
# a283 : comme f62-banc/autres-bancs/a210/run.sh (a226-banc/avant.sh autour du lanceur), mais avec le lanceur intérieur d a283.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a226-banc/avant.sh" "$(cd "$(dirname "$0")" && pwd)/inner.sh" "${1:-/f/StealAShop}"
