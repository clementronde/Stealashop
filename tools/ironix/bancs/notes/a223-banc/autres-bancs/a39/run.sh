#!/usr/bin/env bash
# Copie d'a223 (2026-11-16, vague 66, L-210 point 7) : descendre de la plaque ShopPad ferme la boutique (Leave des
# armes, des auras et de la boutique Robux), pas d'ouverture en poursuite. Scénario pads corrigé par
# a223-banc/patches/a39.sed (3 fermetures à distance devenues des fermetures à la descente, bouton du HUD qui
# rouvre) et complété par a223-banc/patches/a39.post.luau (poursuite, boutique ouverte au HUD). Sans
# WeaponShopController.Leave (arbre d'avant a223) : le lanceur d'avant, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'function WeaponShopController.Leave' "$REPO/src/client/Controllers/WeaponShopController.luau" 2>/dev/null; then
	exec bash "$H/a208-banc/autres-bancs/a39/run.sh" "$@"
fi
exec bash "$H/a223-banc/corrige.sh" a39 bash "$H/a208-banc/autres-bancs/a39/run.sh" "$@"
