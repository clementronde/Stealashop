#!/usr/bin/env bash
# a176 (2026-11-15, vague 54, plus de coffre-fort) : banc a96 ($H/a159-banc/autres-bancs/a96/run.sh) avec les correctifs de a176-banc/patches/a96.sed
# (a176-banc/lanceur.sh) ; arbre avec PvP.VaultSlots : le banc tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a176-banc/lanceur.sh" a96 "$H/a159-banc/autres-bancs/a96/run.sh" "$@"
