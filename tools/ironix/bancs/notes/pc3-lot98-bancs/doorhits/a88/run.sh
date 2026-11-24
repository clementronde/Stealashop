#!/usr/bin/env bash
H="$(cd "$(dirname "$0")/../../.." && pwd)"
# lot98 (petit chef 3) : a88 avec le faux ToolService.GetDoorHits d'a407 (a407-banc/corrige.sh, patches/a159.sed).
exec bash "$H/a407-banc/corrige.sh" a159 bash "$H/a229-banc/autres-bancs/a88/run.sh" "$@"
