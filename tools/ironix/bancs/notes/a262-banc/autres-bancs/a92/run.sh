#!/usr/bin/env bash
# a262 (vague 76, 2026-11-19) : banc a92 d'avant la vague 76 (a92-banc/run.sh), corrigé à la volée par a262-banc/corrige.sh
# (attribut Tier rendu d'après BoxRarity, puis a262-banc/patches/a92.pl s'il existe). Arbre sans la vague 76 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a262-banc/corrige.sh" "a92" "$S/a92-banc/run.sh" "$@"
