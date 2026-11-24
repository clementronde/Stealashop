#!/usr/bin/env bash
# a203 (vague 62) : lance le banc <nom> (lanceur d'avant a203, chemin relatif au dossier des bancs) via ../corrige.sh.
#   bash lanceur.sh <nom> <lanceur d'avant> [racine du dépôt] [arguments…]
set -u
A="$(cd "$(dirname "$0")/.." && pwd)"
B="$(cd "$A/.." && pwd)"
NAME="$1"
PREV="$2"
shift 2
exec bash "$A/corrige.sh" "$NAME" "$B/$PREV" "$@"
