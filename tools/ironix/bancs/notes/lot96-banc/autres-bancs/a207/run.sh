#!/usr/bin/env bash
# lot96 : a207 (copie f67) corrigé par ../../corrige.sh (patches/a207.pl : MutationRow et DetailMutations d a410 tolérés).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot96-banc/corrige.sh" a207 bash "$N/f67-banc/autres-bancs/a207/run.sh" "$@"
