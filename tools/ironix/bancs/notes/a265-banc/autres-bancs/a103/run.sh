#!/usr/bin/env bash
# a265 (vague 79, 2026-11-20) : banc a103 de la fusion77 (a264-banc/autres-bancs/a103/run.sh), corrigé à la volée par a265-banc/corrige.sh
# (patches/a103.pl : cas R6a à R6e, GrabItem par étapes ; K2g, K2h et K2c, GrabDropped par étapes). Arbre sans le correctif a265 de StoreHeistService : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a265-banc/corrige.sh" "a103" "$S/a264-banc/autres-bancs/a103/run.sh" "$@"
