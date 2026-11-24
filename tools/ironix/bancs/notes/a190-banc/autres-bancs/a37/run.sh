#!/usr/bin/env bash
# a190 (vague 59) : lanceur du banc a37 corrigé par ../../patches/a37.sed (voir ce fichier).
# Arbre d'avant a190 (pas de Config/Hud.luau) : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/Config/Hud.luau" ]; then
	exec bash "$H/a181-banc/autres-bancs/a37/run.sh" "$@"
fi
exec bash "$H/a190-banc/corrige.sh" a37 bash "$H/a181-banc/autres-bancs/a37/run.sh" "$@"
