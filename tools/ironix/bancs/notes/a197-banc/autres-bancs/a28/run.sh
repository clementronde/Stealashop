#!/usr/bin/env bash
# a197 (2026-11-15, vague 60) : banc a28 ($H/a172-banc/autres-bancs/a28/run.sh) avec les règles du tuto d'avant a197 (a197-banc/lanceur.sh).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a197-banc/lanceur.sh" "$H/a172-banc/autres-bancs/a28/run.sh" "$@"
