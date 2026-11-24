#!/usr/bin/env bash
# a291 : lanceur du banc a134 d'avant (a262-banc/autres-bancs-cantin/a134/run.sh) corrigé par ../../patches/a134.sed
# (Fortune Tower pour 6 joueurs d'a286 : 3 casseurs, MaxHP 2.7B au lieu de 3.6B). Arbre encore à 8 caisses
# (LootCount = 8) : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q 'LootCount = 8,' "$REPO/src/shared/Config/FortuneTower.luau" 2>/dev/null; then
	exec bash "$H/a262-banc/autres-bancs-cantin/a134/run.sh" "$@"
fi
exec bash "$H/a291-banc/corrige.sh" a134 bash "$H/a262-banc/autres-bancs-cantin/a134/run.sh" "$@"
