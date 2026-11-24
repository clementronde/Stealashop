#!/usr/bin/env bash
# a264 (vague 78, 2026-11-20) : banc pc-steal de la fusion75 (a262-banc/autres-bancs/pc-steal/run.sh), corrigé à la volée par
# a264-banc/corrige.sh (patches/pc-steal.pl : cas V1 à V5, invite « Steal » coupée tant que l'objet vole vers son rayon).
# Arbre sans le correctif a264 de HeistController : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a264-banc/corrige.sh" "pc-steal" "$S/a262-banc/autres-bancs/pc-steal/run.sh" "$@"
