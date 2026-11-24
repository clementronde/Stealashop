#!/usr/bin/env bash
# a265 (vague 79, 2026-11-20) : banc a29 de la fusion77 (a262-banc/autres-bancs/a29/run.sh), corrigé à la volée par a265-banc/corrige.sh
# (patches/a29.pl : cas S1 et maintien de la prise, StealItem par étapes). Arbre sans le correctif a265 de StoreHeistService : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a265-banc/corrige.sh" "a29" "$S/a262-banc/autres-bancs/a29/run.sh" "$@"
