#!/usr/bin/env bash
# a218 (vague 66) : banc a19 corrigé par ../../patches/anciennes-auras.sed (lanceur d'avant : a212-banc/autres-bancs/a19/run.sh).
# Arbre où Features.NewAuras n'est pas à true (avant la vague 66) : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q '^[[:space:]]*NewAuras = true,' "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a212-banc/autres-bancs/a19/run.sh" "$@"
fi
exec bash "$H/a218-banc/corrige.sh" anciennes-auras bash "$H/a212-banc/autres-bancs/a19/run.sh" "$@"
