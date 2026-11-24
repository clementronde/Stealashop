#!/usr/bin/env bash
# a253 (vague 73, L-243 a et b) : banc a208 (lanceur d'a218) corrigé par ../../patches/a208.sed. Arbre sans « Buy x%d »
# dans RobuxShopController (avant la fusion d'a253) : le lanceur d'a218 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'Buy x%d' "$REPO/src/client/Controllers/RobuxShopController.luau" 2>/dev/null; then
	exec bash "$H/a218-banc/autres-bancs/a208/run.sh" "$@"
fi
exec bash "$H/a253-banc/corrige.sh" a208 bash "$H/a218-banc/autres-bancs/a208/run.sh" "$@"
