#!/usr/bin/env bash
# a294 (21/11) : le lanceur d avant (a285-banc/autres-bancs/a208/run.sh) corrigé par ../../patches/a208.sed (chances
# validées par Cantin dans Config/Monetization). Arbre sans a294 (pas de RobuxCrateDev) : le lanceur d avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'RobuxCrateDev = ' "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a285-banc/autres-bancs/a208/run.sh" "$@"
fi
exec bash "$H/a294-banc/corrige.sh" a208 bash "$H/a285-banc/autres-bancs/a208/run.sh" "$@"
