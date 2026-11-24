#!/usr/bin/env bash
# a262 (vague 76, 2026-11-19) : banc pc-steal d'avant la vague 76 (a251-banc/autres-bancs/pc-steal/run.sh), corrigé à la volée par a262-banc/corrige.sh
# (attribut Tier rendu d'après BoxRarity, puis a262-banc/patches/pc-steal.pl s'il existe). Arbre sans la vague 76 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a262-banc/corrige.sh" "pc-steal" "$S/a251-banc/autres-bancs/pc-steal/run.sh" "$@"
