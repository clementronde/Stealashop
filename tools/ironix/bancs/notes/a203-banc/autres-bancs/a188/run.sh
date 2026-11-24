#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a188, via ../lanceur.sh (lanceur d avant : a188-banc/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a188 a188-banc/run.sh "$@"
