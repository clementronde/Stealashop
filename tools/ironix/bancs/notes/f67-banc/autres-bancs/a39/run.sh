#!/usr/bin/env bash
# fusion67 (vague 72) : banc a39 avec les trois correctifs, emboîtés.
#   a238 (vague 71) : a238-banc/autres-bancs/a39 (Ouvrir maintenant sans colis : bouton au premier palier), autour de la copie f62 ;
#   a243 (vague 72) : a243-banc/autres-bancs/a39 (fiche Trap à la fin de Models.List), posé autour du lanceur a238 ;
#   a244 (vague 72) : a244-banc/autres-bancs/flag-off.sh (copie de l arbre à Features.Rebirth = false), posé autour de tout.
# Chacun se replie sur le lanceur d avant quand son changement n est pas dans l arbre (pas de NoItemPrice, pas de
# Config/Traps, pas de « Rebirth = true, »). a247 : SERVER_LUCK éteint en V0, rien à changer.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a244-banc/autres-bancs/flag-off.sh" "$H/a243-banc/autres-bancs/a39/run.sh" "$@"
