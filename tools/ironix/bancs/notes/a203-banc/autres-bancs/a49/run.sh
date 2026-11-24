#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a49, via ../lanceur.sh (lanceur d avant : a176-banc/autres-bancs/a49/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a49 a176-banc/autres-bancs/a49/run.sh "$@"
