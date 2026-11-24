#!/usr/bin/env bash
# lot98 (petit chef 3) : a190 (lanceur a224) + pc3-lot98-bancs/patches/a190.pl (copie corrigée du correctif d'a319 :
# M1d et M5, x2 SPEED devenu le gamepass DoubleSpeed). Remplace a319-banc/autres-bancs/a190, dont la regex de M5 ne
# trouvait jamais la section.
H="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$H/pc3-lot98-bancs/corrige.sh" a190 bash "$H/a224-banc/autres-bancs/a190/run.sh" "$@"
