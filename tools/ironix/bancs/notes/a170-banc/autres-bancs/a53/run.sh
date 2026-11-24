#!/usr/bin/env bash
# a170 (2026-11-15, vague 52, lot D : fin du colis porté côté client et contrat) : lanceur du banc a53.
# Avant a170 (remote BoxReady encore dans Net/Definitions) : le lanceur d'avant (a158-banc/autres-bancs/a53/run.sh), tel quel.
# Depuis a170 : ../../corrige.sh (patches/commun.sed et patches/a53.sed s'il existe) autour du même lanceur.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q 'Name = "BoxReady"' "$REPO/src/shared/Net/Definitions.luau" 2>/dev/null; then
	exec bash "$H/a158-banc/autres-bancs/a53/run.sh" "$@"
fi
exec bash "$H/a170-banc/corrige.sh" a53 bash "$H/a158-banc/autres-bancs/a53/run.sh" "$@"
