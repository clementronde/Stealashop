#!/usr/bin/env bash
# a262 (vague 76, 2026-11-19) : banc a130 d'avant la vague 76 (f57-banc/autres-bancs/a130/run.sh), corrigé à la volée par a262-banc/corrige.sh
# (attribut Tier rendu d'après BoxRarity, puis a262-banc/patches/a130.pl s'il existe). Arbre sans la vague 76 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a262-banc/corrige.sh" "a130" "$S/f57-banc/autres-bancs/a130/run.sh" "$@"
