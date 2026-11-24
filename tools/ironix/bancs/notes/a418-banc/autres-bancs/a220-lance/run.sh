#!/usr/bin/env bash
# a418 (23/11, variante A2 : Config/Reveal.Shelf.MinScale 2,1) : banc a220 (copie dans a418-banc/autres-bancs/a220 : l'objet
# qui casse le dessus du rayon passe de ×2 à ×2,5, et ×2 ne casse rien), lancé comme dans le lanceur commun par
# f70c4-banc/corrige.sh (Return.Time = 0).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)"
bash "$N/f70c4-banc/corrige.sh" a220 bash "$N/a418-banc/autres-bancs/a220/run.sh" "$@"
