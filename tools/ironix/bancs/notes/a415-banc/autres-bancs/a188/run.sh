#!/usr/bin/env bash
# a415 (23/11, retrait du lâcher volontaire) : banc a188 par la chaîne d'avant (a262-banc/autres-bancs/a188/run.sh),
# corrigé à la volée par a415-banc/corrige.sh et patches/a188.pl (lâcher Drop(joueur, nil, "Released") remplacé par une
# chute de batte, raison « Bat »). Arbre d'avant a415 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a415-banc/corrige.sh" "a188" "$S/a262-banc/autres-bancs/a188/run.sh" "$@"
