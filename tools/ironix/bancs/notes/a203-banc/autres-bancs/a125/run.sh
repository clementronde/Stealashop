#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a125, via ../lanceur.sh (lanceur d avant : a125-banc/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a125 a125-banc/run.sh "$@"
