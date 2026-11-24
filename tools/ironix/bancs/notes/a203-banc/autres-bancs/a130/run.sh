#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a130, via ../lanceur.sh (lanceur d avant : a158-banc/autres-bancs/a130/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a130 a158-banc/autres-bancs/a130/run.sh "$@"
