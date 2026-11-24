#!/usr/bin/env bash
# a176 (2026-11-15, vague 54, plus de coffre-fort) : banc a85 ($H/a159-banc/autres-bancs/a85/run.sh) avec les correctifs de a176-banc/patches/a85.sed
# (a176-banc/lanceur.sh) ; arbre avec PvP.VaultSlots : le banc tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a176-banc/lanceur.sh" a85 "$H/a159-banc/autres-bancs/a85/run.sh" "$@"
