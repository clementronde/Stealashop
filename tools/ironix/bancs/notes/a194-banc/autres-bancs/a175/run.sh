#!/usr/bin/env bash
# Copie a194 (2026-11-15, vague 60) du banc a175 : scénario exit lu ici (sections 2 et 3 : plus de laisse ni d'abandon pour
# un porteur, fin au dépôt), précédé du prélude d'a177, sur la copie a175 du banc a124. Arbre sans Defense.ChaseToEnd :
# le banc a175 tourne tel quel.
#   bash run.sh [racine du dépôt]
H="$(cd "$(dirname "$0")" && pwd)"
N="$H/../../.."
ROOT="${1:-/f/StealAShop}"
if ! grep -q "ChaseToEnd" "$ROOT/src/shared/Config/Bot.luau" 2>/dev/null; then exec bash "$N/a175-banc/run.sh" "$@"; fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat "$N/a177-banc/autres-bancs/a124/prelude.luau" "$H/tests.exit.luau" > "$TMP/tests.exit.luau"
out=$(A149_TESTS="$TMP" bash "$N/a175-banc/autres-bancs/a124/run.sh" "$ROOT" exit 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^  exit|arrêté" || true
line=$(printf '%s\n' "$out" | tail -1)
c=$(printf '%s' "$line" | sed -E 's/.*: ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a175 (bot à la sortie) : $c vérification(s), $f échec(s)"
exit $((f > 0))
