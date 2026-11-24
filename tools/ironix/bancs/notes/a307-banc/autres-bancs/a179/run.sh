#!/usr/bin/env bash
# Copie a307 (22/11, L-285) du banc a179 : il attend l'ancien fond de la boutique (sans fond minimum) ; lancé tel quel
# (a195-banc/autres-bancs/a179-banc/run.sh) sur une copie de l'arbre à Config/ShopGrowth.MinBack = nil. Le fond minimum est vérifié par le banc a307.
# Sans MinBack dans l'arbre : le banc d'origine, sans copie.
set -eu
D="$(cd "$(dirname "$0")" && pwd)"
exec bash "$D/../../sans-minback.sh" "$D/../../../a195-banc/autres-bancs/a179-banc/run.sh" "${1:-/f/StealAShop}"
