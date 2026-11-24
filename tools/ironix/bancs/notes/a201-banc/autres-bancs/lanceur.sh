#!/usr/bin/env bash
# a201 (vague 61, L-192) : lanceur commun des bancs a55, a67, a73, a117 et a171 (autres-bancs/<nom>/run.sh l'appellent).
# Sans la marque d'a201 dans Config/Index (« L-192 ») : le lanceur d'a191 tel quel (a191-banc/autres-bancs/<nom>/run.sh).
# Avec : ../corrige.sh (patches/index.sed et patches/<nom>.sed d'a201) autour du même lanceur d'a191.
#   bash lanceur.sh <nom> [racine du dépôt] [scénarios…]
NAME="$1"
shift
H="$(cd "$(dirname "$0")/../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "L-192" "$REPO/src/shared/Config/Index.luau" 2>/dev/null; then
	exec bash "$H/a191-banc/autres-bancs/$NAME/run.sh" "$@"
fi
exec bash "$H/a201-banc/corrige.sh" "$NAME" bash "$H/a191-banc/autres-bancs/$NAME/run.sh" "$@"
