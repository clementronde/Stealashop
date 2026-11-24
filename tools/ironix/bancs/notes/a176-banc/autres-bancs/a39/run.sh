#!/usr/bin/env bash
# a176 (2026-11-15, vague 54, plus de coffre-fort) : banc a39 ($H/a172-banc/autres-bancs/a39/run.sh) avec les correctifs de a176-banc/patches/a39.sed
# (a176-banc/lanceur.sh) ; arbre avec PvP.VaultSlots : le banc tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a176-banc/lanceur.sh" a39 "$H/a172-banc/autres-bancs/a39/run.sh" "$@"
