#!/usr/bin/env bash
# a257 (vague 74) : sur un arbre à Config/Unbox.New.ActionsByRarity (nombre d'actions selon le résultat, plus de mots),
# le banc a251 est remplacé par sa copie corrigée, le banc a257 (qui passe déjà par f70c4-banc/corrige.sh). Arbre sans
# a257 : le lanceur d'avant (f70c4-banc/autres-bancs/a251).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if grep -q "ActionsByRarity" "$ROOT/src/shared/Config/Unbox.luau" 2>/dev/null; then
	echo "banc a251 : remplacé par le banc a257 (sa copie corrigée) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
exec bash "$N/f70c4-banc/autres-bancs/a251/run.sh" "$@"
