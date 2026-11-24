#!/usr/bin/env bash
# Banc hors Studio de pc-reach (2026-11-14, décision de Cantin : ouvrir un colis en courant). Portée souple au
# début et pendant le maintien (tolérance min(WalkSpeed × (ping + ReachLatencyPad), plafond), plafond = max(ReachToleranceMin, WalkSpeed × ReachToleranceSeconds), en plus
# de GrabMaxDistance, volume Bounds agrandi d'autant), stricte à la fin. OpenShelfBox, GrabItem, GrabDropped (BatService).
# Mise en place : celle de la copie a134 du banc a103 (comme le banc a116, serveur), lue sur place ; pre.reach.luau
# ajoute Player:GetNetworkPing() au faux Roblox ; scénarios reach (tests.reach.luau) et zero (GrabTime 0 dans le faux arbre, pre.zero.luau).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
# pc-cantin (2026-11-14) : plafond = max(ReachToleranceMin, WalkSpeed × ReachToleranceSeconds) ; R4 (plafond 8 à 10 studs/s, 14,4 à 18 studs/s ; valeurs 0,8 s du 14/11 : R3, R4 et R6c à basse vitesse pour rester dans Bounds), R7 (65 studs/s, plafond 52 :
# début à 15,7 accepté, fin à 12,6 refusée, tricheur à 15 studs refusé) ; chrono du vigile à 40 s dans le faux arbre (pre.reach.luau).
# Arbre sans Balance.Heist.ReachToleranceSeconds (plafond qui suit la vitesse, pc-cantin) : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LABEL="banc pc-reach (portée au début du maintien)"
if ! grep -q "ReachToleranceSeconds" "$SRC/shared/Config/Balance.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (pas de ReachToleranceSeconds dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCEN="${SCEN:-reach zero}"
S="$H/../a134-banc/autres-bancs/a103"
A134DIR="$(cd "$H/../a134-banc" && pwd)"
NOTESDIR="$(cd "$H/.." && pwd)"
TMPS="$(mktemp -d)"
trap 'rm -rf "$TMPS"' EXIT
cp "$S/run.sh" "$S/head.luau" "$TMPS/"
for s in $SCEN; do cp "$H/pre.$s.luau" "$TMPS/pre.$s.luau"; cp "$H/tests.$s.luau" "$TMPS/tests.$s.luau"; done
sed -i "s#^H=.*#H=\"$TMPS\"#; s#^NOTES=.*#NOTES=\"$NOTESDIR\"#; s#^LABEL=.*#LABEL=\"$LABEL\"#" "$TMPS/run.sh"
sed -i 's#"$H/\.\./\.\./levier-force\.luau"#"'"$A134DIR"'/levier-force.luau"#; s#"$H/\.\./\.\./coups-en-rafale\.luau"#"'"$A134DIR"'/coups-en-rafale.luau"#' "$TMPS/run.sh"
bash "$TMPS/run.sh" "$ROOT" $SCEN
