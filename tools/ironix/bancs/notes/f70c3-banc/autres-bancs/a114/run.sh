#!/usr/bin/env bash
# f70c3b : lanceur du banc a114 (a241-banc/autres-bancs/a114/run.sh) sur une copie de l'arbre à
# Chase.ApproachSlowNear = true (f70c3-banc/lent.sh) : son faux Roblox ne donne aucune vitesse aux joueurs
# (AssemblyLinearVelocity toujours nulle), tout voleur y semble arrêté ; L6d (Bob plus rapide que le vigile, gardé
# jusqu'à la fin du chrono) supposait l'approche lente. Voleur qui court / arrêté : banc f70c3 (scénario proche).
S="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
shift || true
exec bash "$S/f70c3-banc/lent.sh" "$S/a241-banc/autres-bancs/a114/run.sh" "$ARG" "$@"
