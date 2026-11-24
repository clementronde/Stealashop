#!/usr/bin/env bash
# a173 (2026-11-15, vague 53) : lanceur du banc a168 pour le lanceur commun. Arbre sans a173 (pas de HoldRecallGain) :
# le lanceur d'a172 tel quel. Sinon la copie a173 (S1g, S1h avec le rappel), au travers d'a172-banc/corrige.sh sur un
# arbre sans Features.ShelfOpen, comme le lanceur d'a172.
H="$(cd "$(dirname "$0")" && pwd)"
ALL="$(cd "$H/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "HoldRecallGain" "$REPO/src/shared/Config/Chase.luau" 2>/dev/null; then
	exec bash "$ALL/a172-banc/autres-bancs/a168/run.sh" "$@"
fi
if grep -q "ShelfOpen = true" "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/run.sh" "$@"
fi
exec bash "$ALL/a172-banc/corrige.sh" a168 bash "$H/run.sh" "$@"
