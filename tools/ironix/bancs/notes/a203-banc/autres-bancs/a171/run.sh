#!/usr/bin/env bash
# a203 (vague 62, le poids) : banc a171, via ../lanceur.sh (lanceur d avant : a198-banc/autres-bancs/a171/run.sh ; arbre sans ItemWeight : tel quel).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/lanceur.sh" a171 a198-banc/autres-bancs/a171/run.sh "$@"
