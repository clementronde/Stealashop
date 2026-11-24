#!/usr/bin/env bash
# a265 (vague 79, 2026-11-20) : banc a116 de la fusion77 (a263-banc/autres-bancs/a116/run.sh), corrigé à la volée par a265-banc/corrige.sh
# (patches/a116.pl : cas H6a à H6d, OpenShelfBox par étapes). Arbre sans le correctif a265 de StoreHeistService : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a265-banc/corrige.sh" "a116" "$S/a263-banc/autres-bancs/a116/run.sh" "$@"
