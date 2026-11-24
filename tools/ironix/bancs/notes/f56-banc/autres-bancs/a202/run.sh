#!/usr/bin/env bash
# fusion56 (vague 62) : banc a202 corrigé par ../../patches/a202.sed (doublure d'ItemWeight appuyée sur le vrai module d'a203).
# Arbre sans a203 (pas de Config/Weight) : le banc a202 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/Config/Weight.luau" ]; then
	exec bash "$H/a202-banc/run.sh" "$@"
fi
exec bash "$H/f56-banc/corrige.sh" a202 bash "$H/a202-banc/run.sh" "$@"
