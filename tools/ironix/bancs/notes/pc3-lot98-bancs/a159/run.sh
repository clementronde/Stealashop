#!/usr/bin/env bash
# lot98 (petit chef 3) : a159 du lot97 (a284, regen10.sh) avec le faux ToolService.GetDoorHits d'a407 (corrige.sh).
H="$(cd "$(dirname "$0")/../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/a407-banc/corrige.sh" a159 bash "$H/a284-banc/regen10.sh" "$H/a183-banc/autres-bancs/a159/run.sh" "$ARG"
