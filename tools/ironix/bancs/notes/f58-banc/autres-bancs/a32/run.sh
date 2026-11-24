#!/usr/bin/env bash
# fusion58 (vague 64) : banc a32 via a212-banc/corrige.sh, VIDEO_RHYTHM = false (ses tests lisent l'ancien rythme d'ouverture en dur ; lanceur d'avant : a198-banc/autres-bancs/a32/run.sh ; arbre sans VideoRhythm : tel quel).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/a212-banc/corrige.sh" a32 "$N/a198-banc/autres-bancs/a32/run.sh" "$@"
