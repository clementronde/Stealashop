#!/usr/bin/env bash
# a190 (vague 59) : lanceur du banc a60 corrigé par ../../patches/a60.sed (voir ce fichier).
# Arbre d'avant a190 (pas de Config/Hud.luau) : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/Config/Hud.luau" ]; then
	exec bash "$H/a134-banc/autres-bancs/a60/run.sh" "$@"
fi
exec bash "$H/a190-banc/corrige.sh" a60 bash "$H/a134-banc/autres-bancs/a60/run.sh" "$@"
