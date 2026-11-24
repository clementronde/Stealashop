#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : volet vfx : scénarios de la copie a134 d'a20 (auras et trails v2, dégâts = arme × aura, marche en log).
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a73-banc/run.sh" "$@"; fi
# Banc hors Studio d'a73 (2026-11-11, vague 24, retours de Cantin en Play) :
#   - index : scénario a73 de la copie autres-bancs/a40-banc (ZoneName = magasins PNJ de chaque zone, icône
#     de vitesse du HUD dans Rewards.SpeedReward.Icon, IndexButton de LeftRail et de LeftRailTouch) ;
#   - vfx/run.sh : VISUAL EFFECTS sur OFF (auras, lumière d'aura, trails, halos de rareté éteints, rallumés à ON).
# « SAUTÉ » avant la fusion.
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
code=0
out=$(bash "$H/../../../a73-banc/autres-bancs/a40-banc/run.sh" "$ROOT" a73) || code=1
printf '%s\n' "$out" | sed 's/^banc a40 (index des objets)/banc a73 (index : magasins, icône du +3 %, IndexButton)/'
bash "$H/vfx/run.sh" "$ROOT" || code=1
exit $code
