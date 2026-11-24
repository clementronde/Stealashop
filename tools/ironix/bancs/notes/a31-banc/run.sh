#!/usr/bin/env bash
# Banc hors Studio de l'agent a31 (vague 11, liaison L-055) : les deux parties, l'une après l'autre.
#   core/  catalogue à 83 objets, profils v2, contrat, Contract/Icons, ContractChecker (Wave_,
#          ICON_), ItemIdleController (Wave_ sans dérive, pivot des Spin_) ;
#   reel/  icônes dans le rouleau de l'ouverture des colis, séquence complète avec Unbox/Screen.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a31 ; après fusion : /f/StealAShop)
# Pour run-all-bancs.sh : "a31:$H/a31-banc/run.sh:$REPO" (deux lignes de résumé).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a31}"
bash "$H/core/run.sh" "$ROOT"
bash "$H/reel/run.sh" "$ROOT"
