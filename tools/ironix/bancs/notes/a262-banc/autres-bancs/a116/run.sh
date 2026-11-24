#!/usr/bin/env bash
# a262 (vague 76, 2026-11-19) : banc a116 d'avant la vague 76 (f56-banc/autres-bancs/a116/run.sh), corrigé à la volée par a262-banc/corrige.sh
# (attribut Tier rendu d'après BoxRarity, puis a262-banc/patches/a116.pl s'il existe). Arbre sans la vague 76 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a262-banc/corrige.sh" "a116" "$S/f56-banc/autres-bancs/a116/run.sh" "$@"
