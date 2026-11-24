#!/usr/bin/env bash
# a199 (vague 61) : banc a28 avec les règles du tuto d'avant a199 (a199-banc/lanceur.sh, patch ancien) ; repli : a197-banc/autres-bancs/a28/run.sh.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a199-banc/lanceur.sh" ancien "$H/a197-banc/autres-bancs/a28/run.sh" "$H/a172-banc/autres-bancs/a28/run.sh" "$@"
