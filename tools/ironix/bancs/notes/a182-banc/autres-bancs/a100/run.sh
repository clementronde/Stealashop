#!/usr/bin/env bash
# a182 (2026-11-15, vague 56, L-172) : le banc a100 (lanceur a153, a153-banc/autres-bancs/a100/run.sh) sur l'arbre avec
# Witness.Photo.Enabled = false : ses scénarios supposent l'ancien déroulé (regard sur place au premier coup, balade
# dès la fin de l'appel). Le témoin qui s'approche et filme : banc a182. Sans Witness.Photo : le lanceur a153 tel quel.
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
case "$ROOT" in */src) ROOT="${ROOT%/src}" ;; esac
exec bash "$H/a182-banc/regle-coupee.sh" "$H/a153-banc/autres-bancs/a100/run.sh" repo "$ROOT"
