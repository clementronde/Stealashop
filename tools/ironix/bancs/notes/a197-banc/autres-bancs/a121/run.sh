#!/usr/bin/env bash
# a197 (2026-11-15, vague 60) : banc a121 ($H/a176-banc/autres-bancs/a121/run.sh) avec les règles du tuto d'avant a197 (a197-banc/lanceur.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a197-banc/lanceur.sh" "$H/a176-banc/autres-bancs/a121/run.sh" "$@"
