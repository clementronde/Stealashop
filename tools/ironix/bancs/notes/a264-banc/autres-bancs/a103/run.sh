#!/usr/bin/env bash
# a264 (vague 78, 2026-11-20) : banc a103 de la fusion76 (a263-banc/autres-bancs/a103/run.sh), corrigé à la volée par
# a264-banc/corrige.sh (patches/a103.pl : cas K5h et K5i, un appui pendant le vol de retour est refusé et ne laisse
# aucun maintien). Arbre sans le correctif a264 de HeistController : tel quel.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a264-banc/corrige.sh" "a103" "$S/a263-banc/autres-bancs/a103/run.sh" "$@"
