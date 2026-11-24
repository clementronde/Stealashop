#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a167, via ../lanceur.sh (lanceur d avant : a184-banc/autres-bancs/a167/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a167 a184-banc/autres-bancs/a167/run.sh "$@"
