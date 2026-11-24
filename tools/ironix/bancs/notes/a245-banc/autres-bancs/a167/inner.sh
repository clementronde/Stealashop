#!/usr/bin/env bash
# a245 (vague 72) : chaîne d'a203 (lanceur.sh) sur la copie a245-banc/autres-bancs/a167-a184.
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a203-banc/autres-bancs/lanceur.sh" a167 a245-banc/autres-bancs/a167-a184/run.sh "$@"
