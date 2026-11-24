#!/usr/bin/env bash
# a431 (24/11, L-332) : a85 (arbre, écran) du lot 98 (lot98-banc/autres-bancs/a85 : sans-defense, corrige a85, pc3), puis
# ../../patches/a85.pl (a431-banc/corrige.sh) : Labels chiffrés (L-332), « None » au niveau 0, InfoPanel.NodeDesc facultatif.
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/sans-defense.sh" "${1:-/f/StealAShop}" bash "$N/a431-banc/corrige.sh" a85 bash "$N/lot98-banc/corrige.sh" a85 bash "$N/pc3-lot98-bancs/cantin/a85/run.sh"
