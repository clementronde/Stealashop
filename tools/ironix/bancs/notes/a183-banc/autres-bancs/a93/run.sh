#!/usr/bin/env bash
# a183 (2026-11-15, vague 56, L-173, récompenses de renaissance) : banc a93 ($H/a159-banc/autres-bancs/a93/run.sh, scénario walls du banc a84) avec
# les correctifs de a183-banc/patches/a84.sed (joueurs à Rebirths = 10 : Traps demande 4 renaissances) ; arbre sans RequiresRebirth : le banc d avant.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a183-banc/lanceur.sh" a84 "$H/a159-banc/autres-bancs/a93/run.sh" "$@"
