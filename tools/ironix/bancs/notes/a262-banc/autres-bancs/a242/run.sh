#!/usr/bin/env bash
# a262 (vague 76, 2026-11-19) : banc a242 d'avant la vague 76 (a255-banc/autres-bancs/a242/run.sh), corrigé à la volée par a262-banc/corrige.sh
# (attribut Tier rendu d'après BoxRarity, puis a262-banc/patches/a242.pl s'il existe). Arbre sans la vague 76 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a262-banc/corrige.sh" "a242" "$S/a255-banc/autres-bancs/a242/run.sh" "$@"
