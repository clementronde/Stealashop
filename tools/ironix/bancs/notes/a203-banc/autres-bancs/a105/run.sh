#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a105, via ../lanceur.sh (lanceur d avant : a185-banc/autres-bancs/a105/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a105 a185-banc/autres-bancs/a105/run.sh "$@"
