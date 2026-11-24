#!/usr/bin/env bash
# a401 (vague GC4) : banc a81 sur une copie de l'arbre aux interrupteurs d'a401 coupés (a401-coupe.sh : ancien rythme de
# l'encaissement, que ce banc vérifie) ; le nouveau rythme est vérifié par le banc a401. Lanceur d'avant : f58-banc/autres-bancs/a81/run.sh.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a401-banc/a401-coupe.sh" "$H/f58-banc/autres-bancs/a81/run.sh" "$@"
