#!/usr/bin/env bash
# a265 (vague 79, 2026-11-20) : banc pc-steal (a264-banc/autres-bancs/pc-steal/run.sh), corrigé à la volée par a265-banc/corrige.sh (patches/pc-steal.pl :
# PromptButtonHoldEnded ajouté au faux ProximityPrompt, HeistController s'y abonne). Arbre sans a265 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a265-banc/corrige.sh" "pc-steal" "$S/a264-banc/autres-bancs/pc-steal/run.sh" "$@"
