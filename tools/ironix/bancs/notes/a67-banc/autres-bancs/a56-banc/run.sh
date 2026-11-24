#!/usr/bin/env bash
# Copie d'a67 (2026-11-11, vague 23) du banc a56 : avec UI_Index_v3 au contrat, UI_Index_v2 devient
# facultatif → scénarios v2 et v2contract de la copie a67-banc/autres-bancs/a40-banc (v2contract adapté).
# Sur un arbre sans UI_Index_v3 dans Contract/UI, relance le banc d'a56 tel quel : bon avant et après la fusion.
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "UI_Index_v3" "$ROOT/src/shared/Contract/UI.luau" 2>/dev/null; then exec bash "$H/../../../a56-banc/run.sh" "$@"; fi
out=$(bash "$H/../a40-banc/run.sh" "$ROOT" v2 v2contract)
code=$?
printf '%s\n' "$out" | sed 's/^banc a40 (index des objets)/banc a56 (index v2)/'
exit $code
