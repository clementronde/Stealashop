#!/usr/bin/env bash
# a238 (vague 71, L-213 point 1b) : lanceur du banc a39 (celui de f62) corrigé par ../../patches/a39.sed (Ouvrir
# maintenant sans colis : bouton au prix du premier palier). Arbre sans « NoItemPrice » dans RobuxShopController :
# le lanceur d'avant.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'NoItemPrice' "$REPO/src/client/Controllers/RobuxShopController.luau" 2>/dev/null; then
	exec bash "$H/f62-banc/autres-bancs/a39/run.sh" "$@"
fi
exec bash "$H/a238-banc/corrige.sh" a39 bash "$H/f62-banc/autres-bancs/a39/run.sh" "$@"
