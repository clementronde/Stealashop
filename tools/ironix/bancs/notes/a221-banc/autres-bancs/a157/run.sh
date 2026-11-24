#!/usr/bin/env bash
# a221 (2026-11-16, vague 66) : le banc a157 (lanceur d'avant : a202-banc/autres-bancs/a157/run.sh) sur l'arbre avec Witness.Photo.Rush = false :
# sa partie witness compte les sons (aucun pendant le « ? » qui se vide), or le témoin qui fonce photographie (flash et son) dès
# son arrivée. Le témoin qui fonce : banc a221. Sans Photo.Rush : tel quel.
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
case "$ROOT" in */src) ROOT="${ROOT%/src}" ;; esac
exec bash "$H/a221-banc/regle-coupee.sh" "$H/a202-banc/autres-bancs/a157/run.sh" repo "$ROOT"
