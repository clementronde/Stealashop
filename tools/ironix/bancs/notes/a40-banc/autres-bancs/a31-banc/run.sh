#!/usr/bin/env bash
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
