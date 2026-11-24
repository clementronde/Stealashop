#!/usr/bin/env bash
# a196 (vague 60) : lanceur du banc a182 corrigé par ../../patches/a182.sed (Witness.Photo.Bursts = 1).
# Arbre d'avant a196 (pas de Bursts dans Config/Witness) : le lanceur a182 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'Bursts = 2,' "$REPO/src/shared/Config/Witness.luau" 2>/dev/null; then
	exec bash "$H/a182-banc/run.sh" "$@"
fi
exec bash "$H/a196-banc/corrige.sh" a182 bash "$H/a182-banc/run.sh" "$@"
