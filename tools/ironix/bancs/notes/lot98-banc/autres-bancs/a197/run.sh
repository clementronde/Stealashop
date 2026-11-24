#!/usr/bin/env bash
# lot98-commun : a197 (par a226-banc/autres-bancs/a197) corrigé par ../../corrige.sh (patches/a197.pl : texte de l'étape 6, a412).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a197 bash "$N/a226-banc/autres-bancs/a197/run.sh" "$@"
