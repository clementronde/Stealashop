#!/usr/bin/env bash
# Copie d'a48 (2026-11-08, DEV-102) : profil v6 (Offline, gains hors ligne) → version attendue v6 quand Types/Profile a « Offline: Offline ».
# a48 : sur un arbre sans Offline dans Types/Profile, relance la copie précédente (a46-banc/autres-bancs/a31-banc) : bonne avant et après la fusion.
if ! grep -q "Offline: Offline" "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a46-banc/autres-bancs/a31-banc/run.sh" "$@"; fi
# Copie d'a46 (2026-11-08, L-086) : version attendue v5 quand Types/Profile a BoxQueue (colis sur les présentoirs).
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a40-banc/autres-bancs/a31-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a40-banc/autres-bancs/a31-banc/run.sh" "$@"; fi
# Copie d'a40 (DEV-111, 2026-11-08) : core/ adapté au schéma v4 (index des objets : profil v2 chargé en v4, une ligne de
# migration v4 attendue) ; reel/ inchangé, lancé depuis le banc d'a31.
# Copie d'a38 (DEV-100, 2026-11-08) : core/ adapté au schéma de sauvegarde v3 (profil v2 chargé en v3) ;
# reel/ inchangé, lancé depuis le banc d'a31.
# Banc hors Studio de l'agent a31 (vague 11, liaison L-055) : les deux parties, l'une après l'autre.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a38 ; après fusion : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a38}"
bash "$H/core/run.sh" "$ROOT"
bash "$H/../../../a31-banc/reel/run.sh" "$ROOT"
