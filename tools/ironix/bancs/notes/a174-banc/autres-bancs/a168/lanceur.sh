#!/usr/bin/env bash
# a174 (2026-11-15, vague 54) : lanceur du banc a168. Arbre sans a174 (pas de ReturnToShelfAfterCatches dans Config/Chase) :
# le lanceur d'a173 tel quel. Sinon la copie a174 (14 studs, ruée +30 %), comme le lanceur d'a173.
H="$(cd "$(dirname "$0")" && pwd)"
ALL="$(cd "$H/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "ReturnToShelfAfterCatches" "$REPO/src/shared/Config/Chase.luau" 2>/dev/null; then
	exec bash "$ALL/a173-banc/autres-bancs/a168/lanceur.sh" "$@"
fi
if grep -q "ShelfOpen = true" "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/run.sh" "$@"
fi
exec bash "$ALL/a172-banc/corrige.sh" a168 bash "$H/run.sh" "$@"
