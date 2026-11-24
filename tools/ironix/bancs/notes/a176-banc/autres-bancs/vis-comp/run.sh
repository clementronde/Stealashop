#!/usr/bin/env bash
# a176 (2026-11-15, vague 54, plus de coffre-fort) : banc vis-comp ($H/a127-banc/autres-bancs/vis-competences-banc/run.sh) avec les correctifs de a176-banc/patches/vis-comp.sed
# (a176-banc/lanceur.sh) ; arbre avec PvP.VaultSlots : le banc tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a176-banc/lanceur.sh" vis-comp "$H/a127-banc/autres-bancs/vis-competences-banc/run.sh" "$@"
