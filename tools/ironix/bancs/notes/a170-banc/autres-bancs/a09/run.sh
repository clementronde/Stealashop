#!/usr/bin/env bash
# a170 (2026-11-15, vague 52, lot D : fin du colis porté côté client et contrat) : lanceur du banc a09.
# Avant a170 (remote BoxReady encore dans Net/Definitions) : le lanceur d'avant (a134-banc/autres-bancs/a09/run.sh), tel quel.
# Depuis a170 : ../../corrige.sh (patches/commun.sed et patches/a09.sed s'il existe) autour du même lanceur.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q 'Name = "BoxReady"' "$REPO/src/shared/Net/Definitions.luau" 2>/dev/null; then
	exec bash "$H/a134-banc/autres-bancs/a09/run.sh" "$@"
fi
exec bash "$H/a170-banc/corrige.sh" a09 bash "$H/a134-banc/autres-bancs/a09/run.sh" "$@"
