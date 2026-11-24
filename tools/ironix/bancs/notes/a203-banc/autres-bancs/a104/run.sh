#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a104, via ../lanceur.sh (lanceur d avant : a172-banc/autres-bancs/a104/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a104 a172-banc/autres-bancs/a104/run.sh "$@"
