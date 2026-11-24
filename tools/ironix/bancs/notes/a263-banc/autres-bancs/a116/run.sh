#!/usr/bin/env bash
# a263 (vague 77, 2026-11-20) : banc a116 de la fusion75 (a262-banc/autres-bancs/a116/run.sh), corrigé à la volée par
# a263-banc/corrige.sh (patches/a116.pl : maintien refait après « maintien trop court », cas H2d). Arbre sans le
# correctif a263 de StoreHeistService : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a263-banc/corrige.sh" "a116" "$S/a262-banc/autres-bancs/a116/run.sh" "$@"
