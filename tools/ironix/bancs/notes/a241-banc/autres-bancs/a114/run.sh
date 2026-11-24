#!/usr/bin/env bash
# a241 (vague 72) : lanceur du banc a114 (a231-banc/autres-bancs/a114/run.sh) sur un arbre à Config/Chase.ChaseOnEmptyExit = false
# (../../sans-poursuite.sh) : ses scénarios sortent un joueur sans objet pendant le chrono pour vérifier autre chose
# (règle a70 du rideau local, vigile de fin de chrono) ; la nouvelle règle est vérifiée par le banc a241.
S="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
shift || true
exec bash "$S/a241-banc/sans-poursuite.sh" "$S/a231-banc/autres-bancs/a114/run.sh" "$ARG" "$@"
