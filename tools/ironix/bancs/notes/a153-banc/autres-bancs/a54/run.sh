#!/usr/bin/env bash
# a153 (2026-11-14, vague 45) : le banc a54 (a66-banc/autres-bancs/a54-banc/run.sh) sur l'arbre avec Features.GuardChaseV2 = false
# (ancienne vitesse des poursuivants, que ses scénarios supposent ; la nouvelle règle : banc a153). Voir ../../regle-coupee.sh.
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
case "$ROOT" in */src) ROOT="${ROOT%/src}" ;; esac
exec bash "$H/a153-banc/regle-coupee.sh" "$H/a66-banc/autres-bancs/a54-banc/run.sh" repo "$ROOT"
