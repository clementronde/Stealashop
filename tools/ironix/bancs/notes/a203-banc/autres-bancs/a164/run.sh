#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a164, via ../lanceur.sh (lanceur d avant : a183-banc/autres-bancs/a164/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a164 a183-banc/autres-bancs/a164/run.sh "$@"
