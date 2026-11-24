#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a161, via ../lanceur.sh (lanceur d avant : a196-banc/autres-bancs/a161/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a161 a196-banc/autres-bancs/a161/run.sh "$@"
