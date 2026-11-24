#!/usr/bin/env bash
# a287 (2026-11-21) : banc a259 (lanceur a262-banc/autres-bancs/a259) sur une copie de l'arbre aux règles d'avant
# (a287-banc/avant.sh : ActionsByRarity de 1 à 8, OddsClimb coupé) ; les nouvelles sont vérifiées par le banc a287.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a287-banc/avant.sh" "$S/a262-banc/autres-bancs/a259/run.sh" "$@"
