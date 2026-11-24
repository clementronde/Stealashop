#!/usr/bin/env bash
# fusion56 (vague 62) : banc a134 avec a203 (a203-banc/corrige.sh : Config/Mutations requiert maintenant Shared/ItemWeight,
# que le chargeur d a134 ne trouve pas ; ItemWeight et Config/Weight en ligne, poids coupé) par-dessus le lanceur d a198.
# Arbre sans Shared/ItemWeight : le lanceur d a198 tel quel (repli de corrige.sh).
exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a203-banc/autres-bancs/lanceur.sh" a134 a198-banc/autres-bancs/a134/run.sh "$@"
