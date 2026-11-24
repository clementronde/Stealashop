#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a31, via ../lanceur.sh (lanceur d avant : a158-banc/autres-bancs/a31/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a31 a158-banc/autres-bancs/a31/run.sh "$@"
