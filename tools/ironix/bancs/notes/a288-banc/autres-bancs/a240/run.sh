#!/usr/bin/env bash
# a288 (21/11) : le banc a240 avec Crowd.Trigger = "Exit" (l'ancien moment de la foule, inchangé) ; sur un arbre sans
# Crowd.Trigger, le banc tel quel. Le moment « Enter » (V0) est vérifié par le banc a288.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
exec bash "$H/../exit.sh" "$H/../../../a240-banc/run.sh" "${1:-/f/StealAShop}"
