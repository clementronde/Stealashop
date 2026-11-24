#!/usr/bin/env bash
# a415 (23/11, retrait du lâcher volontaire) : banc a192 par la chaîne d'avant (a262-banc/autres-bancs/a192/run.sh),
# corrigé à la volée par a415-banc/corrige.sh et patches/a192.pl (cas M3 : DropButton n'est plus gardé pendant la
# poursuite). Arbre d'avant a415 : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a415-banc/corrige.sh" "a192" "$S/a262-banc/autres-bancs/a192/run.sh" "$@"
