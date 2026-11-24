#!/usr/bin/env bash
# a286 : lanceur du banc a171 d'avant (a262-banc/autres-bancs-cantin/a171/run.sh) corrigé par ../../patches/a171.sed (Fortune Tower pour 6 joueurs :
# 3 casseurs, MaxHP 2.7B, 6 caisses). Arbre encore à 8 caisses (LootCount = 8) : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q 'LootCount = 8,' "$REPO/src/shared/Config/FortuneTower.luau" 2>/dev/null; then
	exec bash "$H/a262-banc/autres-bancs-cantin/a171/run.sh" "$@"
fi
exec bash "$H/a286-banc/corrige.sh" a171 bash "$H/a262-banc/autres-bancs-cantin/a171/run.sh" "$@"
