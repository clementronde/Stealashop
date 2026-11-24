#!/usr/bin/env bash
# a183 (2026-11-15, vague 56, L-173, récompenses de renaissance) : banc a39 ($H/a181-banc/autres-bancs/a39/run.sh, qui passe lui-même par a176) avec, en plus,
# les correctifs de a183-banc/patches/a39.sed (a183-banc/lanceur.sh) ; arbre sans RequiresRebirth dans Config/SkillTree : le banc d'avant.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a183-banc/lanceur.sh" a39 "$H/a181-banc/autres-bancs/a39/run.sh" "$@"
