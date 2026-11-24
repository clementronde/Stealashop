#!/usr/bin/env bash
# a296 : lanceur du banc a286 d'avant (a286-banc/run.sh) corrigé par ../../patches/a286.sed (Features.NewTraps coupé,
# NewTrapsDev allumé, prime au complice allumée, colle gardée). Arbre sans NewTrapsDev : la copie d'a293, telle quelle.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'NewTrapsDev = true,' "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a293-banc/autres-bancs/a286/run.sh" "$@"
fi
exec bash "$H/a296-banc/corrige.sh" a286 bash "$H/a286-banc/run.sh" "$@"
