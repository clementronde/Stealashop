#!/usr/bin/env bash
# Banc a194 (2026-11-15, vague 60, Cantin : le bot) sur la copie a194 du banc a124 :
#   breaker : pendant la casse de sa porte, le bot ne bouge pas (ni poursuite, ni batte, ni interdiction) ; prise dans la
#             boutique : rien ; sortie avec l'objet : poursuite ;
#   chase   : poursuite jusqu'au bout : capture loin de la boutique, dépôt chez soi, zone safe étrangère ; la zone safe du
#             hub (qui contient la boutique) n'arrête rien.
# Le vrai propriétaire frappe toujours le casseur : scénario owner du banc a177 (copie a194 dans autres-bancs/a177).
# « SAUTÉ » sur un arbre sans Defense.ChaseToEnd.
#   bash run.sh [racine du dépôt] [scénarios…]
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
if ! grep -q "ChaseToEnd" "$ROOT/src/shared/Config/Bot.luau" 2>/dev/null; then
	echo "banc a194 SAUTÉ : cet arbre n'a pas encore la vague 60 (a194)"
	echo "banc a194 (bot : casseur ignoré, poursuite jusqu'au bout) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
out=$(bash "$H/autres-bancs/a124/run.sh" "$ROOT" ${*:-breaker chase} 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|contrôles|arrêté" || true
line=$(printf '%s\n' "$out" | grep -E "^banc a124 .* : [0-9]+ vérification" | tail -1)
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
[ -z "$line" ] && { printf '%s\n' "$out" | tail -20; c=0; f=1; }
echo "banc a194 (bot : casseur ignoré, poursuite jusqu'au bout) : $c vérification(s), $f échec(s)"
exit $((f > 0))
