#!/usr/bin/env bash
# a418 (23/11, variante A2 : Config/Reveal.StartScale 2 = la taille de 10 kg) : banc a204 de a246 (copie dans
# a418-banc/autres-bancs/a204 : le contrôle A5 lit la croissance depuis Reveal.StartScale au lieu de 1), lancé comme dans le
# lanceur commun par f70c4-banc/corrige.sh (Return.Time = 0).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)"
bash "$N/f70c4-banc/corrige.sh" a204 bash "$N/a418-banc/autres-bancs/a204/run.sh" "$@"
