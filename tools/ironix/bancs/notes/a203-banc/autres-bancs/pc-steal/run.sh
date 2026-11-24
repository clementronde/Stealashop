#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc pc-steal, via ../lanceur.sh (lanceur d avant : a170-banc/autres-bancs/pc-steal/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" pc-steal a170-banc/autres-bancs/pc-steal/run.sh "$@"
