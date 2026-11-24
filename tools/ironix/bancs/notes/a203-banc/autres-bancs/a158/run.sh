#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a158, via ../lanceur.sh (lanceur d avant : a172-banc/autres-bancs/a158/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a158 a172-banc/autres-bancs/a158/run.sh "$@"
