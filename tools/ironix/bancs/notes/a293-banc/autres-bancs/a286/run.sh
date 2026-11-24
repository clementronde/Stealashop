#!/usr/bin/env bash
# a293 : lanceur du banc a286 d'avant (a286-banc/run.sh) corrigé par ../../patches/a286.sed (Features.NewTraps allumé, colle
# gardée). Arbre sans NewTraps allumé : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'NewTraps = true,' "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a286-banc/run.sh" "$@"
fi
exec bash "$H/a293-banc/corrige.sh" a286 bash "$H/a286-banc/run.sh" "$@"
