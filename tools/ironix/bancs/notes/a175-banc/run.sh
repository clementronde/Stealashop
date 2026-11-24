#!/usr/bin/env bash
# Banc a175 (2026-11-15, vague 54, Cantin : le bot ne poursuit et ne frappe qu'à la sortie de sa boutique avec son objet) :
# scénario exit (tests.exit.luau) sur la copie a175 du banc a124 (A149_TESTS). « SAUTÉ » sur un arbre sans exitStep.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "local function exitStep" "$ROOT/src/server/Services/BotService.luau" 2>/dev/null; then
	echo "banc a175 SAUTÉ : cet arbre n'a pas encore la vague 54 (a175)"
	echo "banc a175 (bot à la sortie) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
# Petit chef (2026-11-15, fusion50) : avec a177 (WindowService.IsBreaking), le bot sort frapper celui qui casse sa porte ;
# comme pour les autres scénarios du bot (a177-banc/autres-bancs/a124), le prélude d'a177 fait casser la porte sans le déranger.
TESTS_DIR="$H"
P177="$H/../a177-banc/autres-bancs/a124/prelude.luau"
if grep -q "function WindowService.IsBreaking" "$ROOT/src/server/Services/WindowService.luau" 2>/dev/null && [ -f "$P177" ]; then
	TESTS_DIR="$(mktemp -d)"
	trap 'rm -rf "$TESTS_DIR"' EXIT
	cat "$P177" "$H/tests.exit.luau" > "$TESTS_DIR/tests.exit.luau"
fi
out=$(A149_TESTS="$TESTS_DIR" bash "$H/autres-bancs/a124/run.sh" "$ROOT" exit 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^  exit|arrêté" || true
line=$(printf '%s\n' "$out" | tail -1)
c=$(printf '%s' "$line" | sed -E 's/.*: ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a175 (bot à la sortie) : $c vérification(s), $f échec(s)"
exit $((f > 0))
