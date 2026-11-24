#!/usr/bin/env bash
# a262 (vague 76, 2026-11-19) : banc pc-reach d'avant la vague 76 (a202-banc/autres-bancs/pc-reach/run.sh), corrigé à la volée par a262-banc/corrige.sh
# (attribut Tier rendu d'après BoxRarity, puis a262-banc/patches/pc-reach.pl s'il existe). Arbre sans la vague 76 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a262-banc/corrige.sh" "pc-reach" "$S/a202-banc/autres-bancs/pc-reach/run.sh" "$@"
