#!/usr/bin/env bash
# a426 : 1re étape de run.sh (arbre déjà à l'échelle 1) : Training.Treadmill.SideEntryOnly coupé (a180), puis etape2.sh.
H="$(cd "$(dirname "$0")" && pwd)"
B="$(cd "$H/.." && pwd)"
exec bash "$B/a180-banc/regle-coupee.sh" "$H/etape2.sh" repo "${1%/src}"
