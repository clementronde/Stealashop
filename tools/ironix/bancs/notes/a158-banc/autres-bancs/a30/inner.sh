#!/usr/bin/env bash
# a158 : le banc a30 avec ses seuls scénarios encore valables (voir run.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a134-banc/autres-bancs/a30/run.sh" "$1" tool nobat swing client
