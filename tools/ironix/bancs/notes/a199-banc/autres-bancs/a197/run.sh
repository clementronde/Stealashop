#!/usr/bin/env bash
# a199 (vague 61) : banc a197 avec les règles du tuto d'avant a199 (a199-banc/lanceur.sh, patch a199) ; repli : a197-banc/run.sh.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a199-banc/lanceur.sh" a199 "$H/a197-banc/run.sh" "$H/a197-banc/run.sh" "$@"
