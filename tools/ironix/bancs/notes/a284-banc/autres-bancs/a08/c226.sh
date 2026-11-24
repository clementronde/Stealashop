#!/usr/bin/env bash
# a284 : comme a226-banc/autres-bancs/a08/run.sh, vers c198.sh à côté.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a226-banc/avant.sh" "$H/a284-banc/autres-bancs/a08/c198.sh" "${1:-/f/StealAShop/src}"
