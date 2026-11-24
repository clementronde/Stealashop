#!/usr/bin/env bash
# a196 (vague 60) : lanceur du banc a80 corrigé par ../../patches/a161.sed (même correctif) (Vfx.Rarest.Pick = "Rarity", Title nil).
# Arbre d'avant a196 (pas de Pick dans Config/Vfx) : le lanceur a80 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'Pick = "Income"' "$REPO/src/shared/Config/Vfx.luau" 2>/dev/null; then
	exec bash "$H/a80-banc/run.sh" "$@"
fi
exec bash "$H/a196-banc/corrige.sh" a161 bash "$H/a80-banc/run.sh" "$@"
