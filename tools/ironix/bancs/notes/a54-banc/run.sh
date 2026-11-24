#!/usr/bin/env bash
# Banc hors Studio d'a54 (2026-11-10, vague 20, L-083 point 3) : la poursuite des conducteurs du camion.
#   guard/ : le vrai GuardService (StartDriverChase : lancement, vitesse, capture et colis perdu,
#            abandons, fondu), faux Roblox d'a45 ;
#   truck/ : le vrai TruckEventService (fin du chrono : quand, sur qui, combien, où ; crochet Chase,
#            alerte de la nuit ; sans GuardService), faux Roblox d'a42 et bouchon de GuardService.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a54 ; après fusion : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a54}"
if ! grep -q "StartDriverChase" "$ROOT/src/server/Services/GuardService.luau" 2>/dev/null; then
	echo "a54 SAUTÉ : cet arbre n'a pas encore la poursuite des conducteurs"
	echo "banc a54 (conducteurs du camion) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
g=$(bash "$H/guard/run.sh" "$ROOT" 2>&1)
t=$(bash "$H/truck/run.sh" "$ROOT" 2>&1)
printf '%s\n' "$g" | grep -E "ÉCHEC|ERREUR|rror" | sed 's/^/  guard /'
printf '%s\n' "$t" | grep -E "ÉCHEC|ERREUR|rror|arrêté" | sed 's/^/  truck /'
gl=$(printf '%s\n' "$g" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
tl=$(printf '%s\n' "$t" | grep -E "vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
gc=$(printf '%s' "$gl" | sed -E 's/^([0-9]+) vérif.*/\1/'); gf=$(printf '%s' "$gl" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
tc=$(printf '%s' "$tl" | sed -E 's/.* ([0-9]+) vérif.*/\1/'); tf=$(printf '%s' "$tl" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
if [ -z "$gl" ]; then echo "  guard : arrêté avant la fin"; gc=0; gf=1; fi
if [ -z "$tl" ]; then echo "  truck : arrêté avant la fin"; tc=0; tf=1; fi
echo "  guard : $gc contrôles, $gf raté(s) ; truck : $tc contrôles, $tf raté(s)"
echo "banc a54 (conducteurs du camion) : $((gc + tc)) vérification(s), $((gf + tf)) échec(s)"
exit $(((gf + tf) > 0))
