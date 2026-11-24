#!/usr/bin/env bash
# Copie a194 (2026-11-15, vague 60) du banc a177 : sans Defense.HitBreaker (le bot ne vise plus le casseur de sa porte),
# le scénario bot n'a plus lieu d'être (remplacé par le scénario breaker d'a194-banc) ; owner, panel et glass tournent
# tels quels. Arbre sans Defense.ChaseToEnd, ou HitBreaker = true : le banc a177 tourne tel quel.
#   bash run.sh [racine du dépôt] [scénarios…]
H="$(cd "$(dirname "$0")" && pwd)"
N="$H/../../.."
ROOT="${1:-/f/StealAShop}"
if ! grep -q "ChaseToEnd" "$ROOT/src/shared/Config/Bot.luau" 2>/dev/null || grep -qE "HitBreaker = true" "$ROOT/src/shared/Config/Bot.luau"; then exec bash "$N/a177-banc/run.sh" "$@"; fi
shift || true
exec bash "$N/a177-banc/run.sh" "$ROOT" ${*:-owner panel glass}
