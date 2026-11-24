#!/usr/bin/env bash
# a265 (vague 79, 2026-11-20) : banc a139 (a262-banc/autres-bancs/a139/run.sh), corrigé à la volée par a265-banc/corrige.sh (patches/a139.pl :
# PromptButtonHoldEnded ajouté au faux ProximityPrompt, HeistController s'y abonne). Arbre sans a265 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a265-banc/corrige.sh" "a139" "$S/a262-banc/autres-bancs/a139/run.sh" "$@"
