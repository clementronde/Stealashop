#!/usr/bin/env bash
# a183 (2026-11-15, vague 56, L-173, récompenses de renaissance) : banc a159 ($H/a159-banc/run.sh) avec les correctifs de
# a183-banc/patches/a159.sed (joueurs à Rebirths = 10 : Curtain demande 1 renaissance) ; arbre sans RequiresRebirth : le banc d avant.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a183-banc/lanceur.sh" a159 "$H/a159-banc/run.sh" "$@"
