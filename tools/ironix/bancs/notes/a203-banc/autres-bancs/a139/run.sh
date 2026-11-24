#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a139, via ../lanceur.sh (lanceur d avant : pc-steal-banc/autres-bancs/a139/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a139 pc-steal-banc/autres-bancs/a139/run.sh "$@"
