#!/usr/bin/env bash
# a199 (vague 61, tuto de 3 min au plus) : lance un banc existant avec les règles du tuto d'avant a199
# (patches/<patch>.sed, appliqué au fichier assemblé par corrige.sh) quand l'arbre a Tutorial.WaitShieldEnd ;
# arbre d'avant a199 : le lanceur de repli tel quel. Les règles nouvelles sont au banc a199.
#   bash lanceur.sh <patch> <lanceur de repli> <lanceur corrigé> <dépôt>
set -u
H="$(cd "$(dirname "$0")" && pwd)"
PATCH="$1"; FALLBACK="$2"; TARGET="$3"; shift 3
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "WaitShieldEnd" "$REPO/src/shared/Config/Tutorial.luau" 2>/dev/null; then
	exec bash "$FALLBACK" "$@"
fi
exec bash "$H/corrige.sh" "$PATCH" bash "$TARGET" "$@"
