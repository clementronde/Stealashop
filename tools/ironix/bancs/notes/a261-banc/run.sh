#!/usr/bin/env bash
# Banc a261 (2026-11-19, vague 75, T-084 raté : le bot coincé derrière sa porte refaite) : scénario porte261 (tests.porte261.luau)
# sur la copie a175 du banc a124 (A149_TESTS), prélude d a177 comme a175. « SAUTÉ » sur un arbre sans BOT_DOOR_GROUP.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
if ! grep -q "BOT_DOOR_GROUP" "$ROOT/src/server/Services/BotService.luau" 2>/dev/null; then
	echo "banc a261 SAUTÉ : cet arbre n'a pas encore la vague 75 (a261)"
	echo "banc a261 (porte du bot traversable par lui) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TESTS_DIR="$(mktemp -d)"
trap 'rm -rf "$TESTS_DIR"' EXIT
cat "$H/../a177-banc/autres-bancs/a124/prelude.luau" "$H/tests.porte261.luau" > "$TESTS_DIR/tests.porte261.luau"
out=$(A149_TESTS="$TESTS_DIR" bash "$H/../a175-banc/autres-bancs/a124/run.sh" "$ROOT" porte261 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^  porte261|arrêté|^\s" || true
line=$(printf '%s\n' "$out" | tail -1)
c=$(printf '%s' "$line" | sed -E 's/.*: ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a261 (porte du bot traversable par lui) : $c vérification(s), $f échec(s)"
exit $((f > 0))
