#!/usr/bin/env bash
# a197 (2026-11-15, vague 60) : banc a126 ($H/a169-banc/autres-bancs/a126/run.sh) avec les règles du tuto d'avant a197 (a197-banc/lanceur.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a197-banc/lanceur.sh" "$H/a169-banc/autres-bancs/a126/run.sh" "$@"
