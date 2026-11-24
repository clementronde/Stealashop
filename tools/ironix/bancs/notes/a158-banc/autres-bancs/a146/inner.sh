#!/usr/bin/env bash
# a158 : le banc a146 avec ses seuls scénarios encore valables (voir run.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a146-banc/run.sh" "$1" fly carrier bat
