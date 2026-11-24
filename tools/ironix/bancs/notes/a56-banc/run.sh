#!/usr/bin/env bash
# Banc hors Studio d'a56 (2026-11-10, vague 20, L-083 points 5 et 6) : IndexController sur UI_Index_v2
# (sections, cartes dans Cards, ScrollTrack animé selon List, repli sur UI_Index) et UI_Index_v2 au
# contrat (UI_Index facultatif), lu par le vrai ContractChecker. Scénarios v2 et v2contract de la copie
# d'a40 (autres-bancs/a40-banc, qui lance aussi les 5 scénarios d'a40 pour l'entrée « a40 »).
# « SAUTÉ » sur un arbre sans UI_Index_v2 dans Contract/UI (avant la fusion).
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
out=$(bash "$H/autres-bancs/a40-banc/run.sh" "$ROOT" v2 v2contract)
code=$?
printf '%s\n' "$out" | sed 's/^banc a40 (index des objets)/banc a56 (index v2)/'
exit $code
