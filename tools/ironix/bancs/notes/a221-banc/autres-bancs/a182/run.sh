#!/usr/bin/env bash
# a221 (2026-11-16, vague 66) : le banc a182 (lanceur d'avant : a196-banc/autres-bancs/a182/run.sh) sur l'arbre avec Witness.Photo.Rush = false : ses
# scénarios supposent l'approche d'a196 et Look à l'arrivée. Le témoin qui fonce : banc a221. Sans Photo.Rush : tel quel.
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
case "$ROOT" in */src) ROOT="${ROOT%/src}" ;; esac
exec bash "$H/a221-banc/regle-coupee.sh" "$H/a196-banc/autres-bancs/a182/run.sh" repo "$ROOT"
