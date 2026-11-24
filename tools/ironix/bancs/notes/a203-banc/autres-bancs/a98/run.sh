#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a98, via ../lanceur.sh (lanceur d avant : a158-banc/autres-bancs/a98/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a98 a158-banc/autres-bancs/a98/run.sh "$@"
