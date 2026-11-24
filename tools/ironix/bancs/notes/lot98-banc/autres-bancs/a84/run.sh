#!/usr/bin/env bash
# lot98-commun (petit chef 2) : a84 (arbre, serveur) sur une copie sans Bodyguards ni CameraRadar (../../sans-defense.sh,
# a408), puis ../../patches/a84.pl (G0b : 7 tuiles au premier anneau, FittingRoom d'a411), puis la chaîne pc3 (doorhits
# d'a407 → cantin → a262 autres-bancs-cantin/a84).
#   bash run.sh [racine du dépôt]
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot98-banc/sans-defense.sh" "${1:-/f/StealAShop}" bash "$N/lot98-banc/corrige.sh" a84 bash "$N/pc3-lot98-bancs/doorhits/a84/run.sh"
