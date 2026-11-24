#!/usr/bin/env bash
# lot98-commun : a316 = copie banc.sh (mots cherchés dans le code seulement) corrigée par ../../corrige.sh (patches/a316.pl :
# PivotOffset dans le faux ScaleTo).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a316 bash "$N/lot98-banc/autres-bancs/a316/banc.sh" "$@"
