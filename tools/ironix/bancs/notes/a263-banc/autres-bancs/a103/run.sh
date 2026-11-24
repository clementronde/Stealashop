#!/usr/bin/env bash
# a263 (vague 77, 2026-11-20) : banc a103 de la fusion75 (a262-banc/autres-bancs/a103/run.sh), corrigé à la volée par
# a263-banc/corrige.sh (patches/a103.pl : cas R4m, maintien de prise vidé après « maintien trop court »). Arbre sans le
# correctif a263 de StoreHeistService : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a263-banc/corrige.sh" "a103" "$S/a262-banc/autres-bancs/a103/run.sh" "$@"
