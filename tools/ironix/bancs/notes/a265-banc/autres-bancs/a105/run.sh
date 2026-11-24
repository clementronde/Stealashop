#!/usr/bin/env bash
# a265 (vague 79, 2026-11-20) : banc a105 de la fusion77 (a262-banc/autres-bancs/a105/run.sh), corrigé à la volée par a265-banc/corrige.sh
# (patches/a105.pl : cas F1 à F3, StealFloorItem par étapes). Arbre sans le correctif a265 de StoreHeistService : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a265-banc/corrige.sh" "a105" "$S/a262-banc/autres-bancs/a105/run.sh" "$@"
