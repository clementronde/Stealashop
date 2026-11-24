#!/usr/bin/env bash
H="$(cd "$(dirname "$0")/../../.." && pwd)"
# lot98 (petit chef 3) : a34 avec le faux ToolService.GetDoorHits d'a407 (a407-banc/corrige.sh, patches/a159.sed).
exec bash "$H/a407-banc/corrige.sh" a159 bash "$H/a198-banc/autres-bancs/a34/run.sh" "$@"
