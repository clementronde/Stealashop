#!/usr/bin/env bash
# a262 (vague 76, 2026-11-19) : banc a238 d'avant la vague 76 (a238-banc/run.sh), corrigé à la volée par a262-banc/corrige.sh
# (attribut Tier rendu d'après BoxRarity, puis a262-banc/patches/a238.pl s'il existe). Arbre sans la vague 76 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a262-banc/corrige.sh" "a238" "$S/a238-banc/run.sh" "$@"
