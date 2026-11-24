#!/usr/bin/env bash
# a401 (vague GC4) : banc a14 sur une copie de l'arbre aux interrupteurs d'a401 coupés (a401-coupe.sh : plaque d'avant,
# Glow allumé un instant et enfoncement sec, que ce banc vérifie ; son faux Roblox n'a pas TweenService) ; l'animation
# de la plaque est vérifiée par le banc a401. Lanceur d'avant : a262-banc/autres-bancs/a14/run.sh.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a401-banc/a401-coupe.sh" "$H/a262-banc/autres-bancs/a14/run.sh" "$@"
