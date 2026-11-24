#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a119, via ../lanceur.sh (lanceur d avant : a119-banc/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a119 a119-banc/run.sh "$@"
