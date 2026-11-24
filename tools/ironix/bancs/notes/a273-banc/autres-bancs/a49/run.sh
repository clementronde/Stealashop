#!/usr/bin/env bash
# a273 (vague GC1, 23/11) : banc a49 (a262-banc/autres-bancs/a49) par ../../corrige.sh (patches/a49.sed : cas « Gold Bar Pyramid »
# muté Gold, mot de mutation pas répété). Arbre sans startsWithWord dans Config/Mutations (avant a273) : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "startsWithWord" "$REPO/src/shared/Config/Mutations.luau" 2>/dev/null; then
	exec bash "$H/a262-banc/autres-bancs/a49/run.sh" "$@"
fi
exec bash "$H/a273-banc/corrige.sh" a49 bash "$H/a262-banc/autres-bancs/a49/run.sh" "$@"
