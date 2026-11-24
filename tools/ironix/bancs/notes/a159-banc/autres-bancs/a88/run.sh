#!/usr/bin/env bash
# Copie a159 (2026-11-14, vague 50, L-163) : le banc a88 par le lanceur a153 (a153-banc/autres-bancs/a88), avec
# TESTS_DIR = ce dossier : tests.effects.luau, section Strength : un coup sur une porte de boutique compte pour 1
# (L-163) ; la potion se vérifie sur l'accroche WindowService.GetHitDamageMultiplier (×1,5, ×3 × 1,5), qui
# reste pour les vitrines PNJ et les événements ; porte de Bob à 40 coups. spawn et pick : copies telles quelles.
# Arbre sans PvP.DoorHits : le lanceur a153 tel quel.
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
case "$ROOT" in */src) ROOT="${ROOT%/src}" ;; esac
if grep -q "DoorHits = " "$ROOT/src/shared/Config/PvP.luau" 2>/dev/null; then export TESTS_DIR="$H"; fi
exec bash "$H/../../../a153-banc/autres-bancs/a88/run.sh" "$@"
