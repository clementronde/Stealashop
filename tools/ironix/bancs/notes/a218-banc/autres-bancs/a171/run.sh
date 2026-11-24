#!/usr/bin/env bash
# a218 (vague 66) : banc a171 corrigé par ../../patches/a171.sed (lanceur d'avant : f57-banc/autres-bancs/a171/run.sh).
# Arbre où Features.NewAuras n'est pas à true (avant la vague 66) : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q '^[[:space:]]*NewAuras = true,' "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/f57-banc/autres-bancs/a171/run.sh" "$@"
fi
exec bash "$H/a218-banc/corrige.sh" a171 bash "$H/f57-banc/autres-bancs/a171/run.sh" "$@"
