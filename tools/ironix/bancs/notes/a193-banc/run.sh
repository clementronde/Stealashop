#!/usr/bin/env bash
# Banc hors Studio d'a193 (2026-11-15, vague 60, T-069 : distance du vigile trompée par le réseau ; Config/Chase
# LagCompensation, LagPingFactor, LagMaxSeconds, LagMaxStuds, LagContactReach ; GuardService.estimatedPosition).
# Harnais du banc a173 copie a174 (lu sur place) : client simulé, le serveur reçoit sa position NET.oneWay s en
# retard, PING[joueur] = NET.oneWay (GetNetworkPing ≈ aller simple). Le client voit le vigile NET.oneWay s en
# retard : « distance vue » = |position vraie du client − position du vigile il y a NET.oneWay s|.
# Retard R = aller-retour = 2 × NET.oneWay. Scénarios (un processus chacun, lancés ensemble) :
#   hold      30, 60, 90 studs/s × R = 0, 100, 200 ms, au-dessus du minimum : distance vue 14 ± 0,5 tant que
#             vitesse × R ≤ LagMaxStuds, sinon 14 + (vitesse × R − LagMaxStuds) ; pas de capture ;
#   catch     30, 60, 90 studs/s × R = 100, 200 ms, bien sous le minimum : capture à la portée vue (4 + l'excès
#             du plafond) et jamais au-delà de la portée vraie d'avant ;
#   collide   le vigile bute sur la copie du voleur (collisions simulées) : capture au contact sous le minimum,
#             aucune au-dessus ;
#   off       Chase.LagCompensation = false : l'ancien comportement (14 studs de la position reçue, distance vue
#             14 + vitesse × R, capture à 4 studs de la position reçue).
# Arbre sans LagCompensation dans Config/Chase : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ARG="${1:-/f/StealAShop}"
ROOT="${ARG%/src}"
shift || true
if ! grep -q "LagCompensation" "$ROOT/src/shared/Config/Chase.luau" 2>/dev/null; then
	echo "banc a193 SAUTÉ : cet arbre n'a pas encore la compensation du retard réseau"
	echo "banc a193 (retard réseau de la poursuite) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
if grep -q "ShelfOpen = true" "$ROOT/src/shared/Config/Features.luau" 2>/dev/null; then
	out=$(bash "$H/chase.sh" "$ROOT" "$@" 2>&1)
else
	out=$(bash "$H/../a172-banc/corrige.sh" a168 bash "$H/chase.sh" "$ROOT" "$@" 2>&1)
fi
printf '%s\n' "$out"
line=$(printf '%s\n' "$out" | grep -E "^poursuite : [0-9]+ vérification" | tail -1)
if [ -z "$line" ]; then
	echo "banc a193 (retard réseau de la poursuite) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a193 (retard réseau de la poursuite) : $c vérification(s), $f échec(s)"
exit $((f > 0))
