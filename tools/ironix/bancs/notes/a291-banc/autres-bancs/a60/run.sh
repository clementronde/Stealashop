#!/usr/bin/env bash
# a291 : lanceur du banc a60 d'avant (a224-banc/autres-bancs/a60/run.sh) corrigé par ../../patches/a60.sed : depuis
# a286 (L-224 point 2), la carte survolée grossit elle-même de 3 % (UiMotion.Hover.CardTo) ; F2b vérifie ce survol de
# carte au lieu de « aucun UIScale ». Arbre sans Hover.CardTo : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'CardTo = ' "$REPO/src/shared/Config/UiMotion.luau" 2>/dev/null; then
	exec bash "$H/a224-banc/autres-bancs/a60/run.sh" "$@"
fi
exec bash "$H/a291-banc/corrige.sh" a60 bash "$H/a224-banc/autres-bancs/a60/run.sh" "$@"
