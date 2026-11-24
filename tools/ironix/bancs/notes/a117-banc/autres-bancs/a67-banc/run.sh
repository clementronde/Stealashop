#!/usr/bin/env bash
if ! grep -q '"ClaimIndexReward"' "${1:-/f/StealAShop}/src/shared/Net/Definitions.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a73-banc/autres-bancs/a67-banc/run.sh" "$@"; fi # a117 : arbre sans a117 → le banc d'origine
# Copie a117 (vague 34, 2026-11-13, L-127) du banc a67 (copie a73) : mêmes scénarios (v3, v3contract, settings,
# settingsoff), lancés sur la copie a117-banc/autres-bancs/a40-v3 (ClaimAllButton et pastilles dans le faux
# UI_Index_v3 ; la prime de zone se réclame).
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
out=$(bash "$H/../a40-v3/run.sh" "$ROOT" v3 v3contract settings settingsoff)
code=$?
printf '%s\n' "$out" | sed 's/^banc a40 (index des objets)/banc a67 (index v3, réglages)/'
exit $code
