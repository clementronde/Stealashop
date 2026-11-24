#!/usr/bin/env bash
# a305 (22/11, Cantin 2026-11-21 : Balance.Heist.Duration de 6 à 10 s) : banc a202 d'avant (a262-banc/autres-bancs/a202/run.sh),
# corrigé à la volée par a305-banc/corrige.sh et a305-banc/patches/a202.sed : G2 vide `catches` juste avant fireOpen
# (la capture d'Alice dans le braquage de G1 encore ouvert, avant toute cinématique, ne compte plus).
# Arbre encore à Duration = 6 : le lanceur d'avant tel quel.
S="$(cd "$(dirname "$0")/../.." && pwd)"
B="$(cd "$S/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if grep -qE "^[[:space:]]*Duration = 6," "$ROOT/src/shared/Config/Balance.luau" 2>/dev/null; then
	exec bash "$B/a262-banc/autres-bancs/a202/run.sh" "$@"
fi
exec bash "$S/corrige.sh" "$S/patches/a202.sed" bash "$B/a262-banc/autres-bancs/a202/run.sh" "$@"
