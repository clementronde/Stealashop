#!/usr/bin/env bash
# a273 (vague GC1, 23/11) : banc a54 (a198-banc/autres-bancs/a54) par ../../corrige.sh (patches/a54.sed : G5a et G5b lisent
# « l'objet du camion » dans le journal d'abandon). Arbre encore à « le colis du camion » dans GuardService : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "ne porte plus l'objet du camion" "$REPO/src/server/Services/GuardService.luau" 2>/dev/null; then
	exec bash "$H/a198-banc/autres-bancs/a54/run.sh" "$@"
fi
exec bash "$H/a273-banc/corrige.sh" a54 bash "$H/a198-banc/autres-bancs/a54/run.sh" "$@"
