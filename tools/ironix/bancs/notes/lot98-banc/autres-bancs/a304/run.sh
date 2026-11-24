#!/usr/bin/env bash
# lot98-commun : a304 (a304-banc) corrigé par ../../corrige.sh (patches/a304.pl : 9 outils, a407).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/corrige.sh" a304 bash "$N/a304-banc/run.sh" "$@"
