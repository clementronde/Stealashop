#!/usr/bin/env bash
# fusion56 : banc a116 avec a202 (arbre à SingleBoxReveal = false, a202-banc/ancien.sh) puis a203 (ItemWeight en ligne, poids coupé, a203-banc/corrige.sh).
# a203-banc/autres-bancs/lanceur.sh garde ses replis (arbre sans ItemWeight : le lanceur d a202 tel quel, qui garde le sien).
exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a203-banc/autres-bancs/lanceur.sh" a116 a202-banc/autres-bancs/a116/run.sh "$@"
