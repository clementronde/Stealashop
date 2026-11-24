#!/usr/bin/env bash
# a197 (2026-11-15, vague 60, tuto : liste des tâches, flèche sur la cible exacte, Passer = une étape) : lance un banc
# existant avec les règles d'avant a197 (patches/ancien.sed, appliqué au fichier assemblé par corrige.sh) quand l'arbre
# a Tutorial.SkipOneStep ; arbre d'avant a197 : le banc tel quel. Les règles nouvelles sont au banc a197.
#   bash lanceur.sh <lanceur du banc> <dépôt>
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ORIG="$1"; shift
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "SkipOneStep" "$REPO/src/shared/Config/Tutorial.luau" 2>/dev/null; then
	exec bash "$ORIG" "$@"
fi
exec bash "$H/corrige.sh" ancien bash "$ORIG" "$@"
