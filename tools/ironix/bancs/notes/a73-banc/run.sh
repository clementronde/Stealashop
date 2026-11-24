#!/usr/bin/env bash
# Banc hors Studio d'a73 (2026-11-11, vague 24, retours de Cantin en Play) :
#   - index : scénario a73 de la copie autres-bancs/a40-banc (ZoneName = magasins PNJ de chaque zone, icône
#     de vitesse du HUD dans Rewards.SpeedReward.Icon, IndexButton de LeftRail et de LeftRailTouch) ;
#   - vfx/run.sh : VISUAL EFFECTS sur OFF (auras, lumière d'aura, trails, halos de rareté éteints, rallumés à ON).
# « SAUTÉ » avant la fusion.
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
code=0
out=$(bash "$H/autres-bancs/a40-banc/run.sh" "$ROOT" a73) || code=1
printf '%s\n' "$out" | sed 's/^banc a40 (index des objets)/banc a73 (index : magasins, icône du +3 %, IndexButton)/'
bash "$H/vfx/run.sh" "$ROOT" || code=1
exit $code
