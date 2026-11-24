#!/usr/bin/env bash
# fusion53 (2026-11-15, vague 59) : lanceur du banc a61 corrigé par ../../patches/a61.sed (voir ce fichier).
# Arbre d'avant a190 (pas de Config/Hud.luau) : le lanceur d'avant (a170-banc/autres-bancs/a61/run.sh), tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if [ ! -f "$REPO/src/shared/Config/Hud.luau" ]; then
	exec bash "$H/a170-banc/autres-bancs/a61/run.sh" "$@"
fi
exec bash "$H/f53-banc/corrige.sh" a61 bash "$H/a170-banc/autres-bancs/a61/run.sh" "$@"
