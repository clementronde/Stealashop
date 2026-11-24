#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a109, via ../lanceur.sh (lanceur d avant : a158-banc/autres-bancs/a109/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a109 a158-banc/autres-bancs/a109/run.sh "$@"
