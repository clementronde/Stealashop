#!/usr/bin/env bash
# Copie a194 (2026-11-15, vague 60, Cantin : le bot ne vise plus le casseur de sa porte et poursuit le voleur sorti avec son
# objet jusqu'au bout) du banc a124, par-dessus la copie a175 (lancée telle quelle), comme la copie a177 : flee et gentle lus
# ici (plus de laisse ni d'abandon à 10 s pour un porteur, fin au dépôt) ; door et grab comme la copie a177 ; chaque
# scénario précédé du prélude d'a177 (inoffensif sans Defense.HitBreaker). Les scénarios breaker et chase d'a194-banc
# passent aussi par ici. Arbre sans Defense.ChaseToEnd (avant a194) : la copie a177 tourne telle quelle.
#   bash run.sh [racine du dépôt] [scénarios…]
H="$(cd "$(dirname "$0")" && pwd)"
N="$H/../../.."
UP="$N/a175-banc/autres-bancs/a124/run.sh"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "ChaseToEnd" "$ROOT/src/shared/Config/Bot.luau" 2>/dev/null; then exec bash "$N/a177-banc/autres-bancs/a124/run.sh" "$@"; fi
shift || true
SCENARIOS="${*:-door grab flee gentle tuto}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for s in $SCENARIOS; do
	[ "$s" = "tuto" ] && continue
	T="$N/a124-banc/tests.$s.luau"
	[ -f "$N/a169-banc/autres-bancs/a124/tests.$s.luau" ] && T="$N/a169-banc/autres-bancs/a124/tests.$s.luau"
	[ -f "$N/a175-banc/autres-bancs/a124/tests.$s.luau" ] && T="$N/a175-banc/autres-bancs/a124/tests.$s.luau"
	[ -f "$H/tests.$s.luau" ] && T="$H/tests.$s.luau"
	[ -f "$H/../../tests.$s.luau" ] && T="$H/../../tests.$s.luau"
	[ -f "$T" ] && cat "$N/a177-banc/autres-bancs/a124/prelude.luau" "$T" > "$TMP/tests.$s.luau"
done
A149_TESTS="$TMP" bash "$UP" "$ROOT" $SCENARIOS
