#!/usr/bin/env bash
# a431 (24/11, L-332) : a84 (arbre, serveur) du lot 98 (lot98-banc/autres-bancs/a84), puis ../../patches/a84.pl
# (a431-banc/corrige.sh) : message d'achat avec le Label chiffré de Cameras 1 (« alert »).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/sans-defense.sh" "${1:-/f/StealAShop}" bash "$N/a431-banc/corrige.sh" a84 bash "$N/lot98-banc/corrige.sh" a84 bash "$N/pc3-lot98-bancs/doorhits/a84/run.sh"
