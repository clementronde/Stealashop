#!/usr/bin/env bash
# lot98-commun : banc pc-steal par la même chaîne que a265-banc/autres-bancs/pc-steal/run.sh (a265, a264, a262, a203,
# a251), avec la copie base.sh d'ici : liste relue des appels ScaleTo côté client + UpgradeController (popSign d'a406).
S="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$S/a265-banc/corrige.sh" "pc-steal" "$S/lot98-banc/autres-bancs/pc-steal/l264.sh" "$@"
