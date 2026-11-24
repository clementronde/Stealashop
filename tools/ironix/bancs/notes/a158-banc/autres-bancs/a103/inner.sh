#!/usr/bin/env bash
# a158 : le banc a103 avec ses seuls scénarios encore valables (voir run.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a134-banc/autres-bancs/a103/run.sh" "$1" open reserve witness caught close
