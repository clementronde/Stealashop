#!/usr/bin/env bash
# lot98-commun : a85 (arbre, écran) de pc3-lot98-bancs/cantin sur une copie sans Bodyguards ni CameraRadar
# (../../sans-defense.sh, a408), corrigé par ../../corrige.sh (patches/a85.pl : SelectionGained et Selectable, a419 ;
# tuile facultative Tile_FittingRoom, a411).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/sans-defense.sh" "${1:-/f/StealAShop}" bash "$N/lot98-banc/corrige.sh" a85 bash "$N/pc3-lot98-bancs/cantin/a85/run.sh"
