#!/usr/bin/env bash
# a183 (2026-11-15, vague 56, L-173, récompenses de renaissance) : banc a84 ($H/a176-banc/autres-bancs/a84/run.sh) avec, en plus,
# les correctifs de a183-banc/patches/a84.sed (a183-banc/lanceur.sh) ; arbre sans RequiresRebirth dans Config/SkillTree : le banc d'avant.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a183-banc/lanceur.sh" a84 "$H/a176-banc/autres-bancs/a84/run.sh" "$@"
