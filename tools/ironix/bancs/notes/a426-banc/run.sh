#!/usr/bin/env bash
# Banc hors Studio d'a426 (24/11, L-319, décision de Clément du 23/11) : dans une zone SafeZone, la même vitesse pour tous
# (Balance.SafeZoneSpeed.WalkSpeed) ; objet pris chez un joueur porté dans la zone : WalkSpeed × StolenItemMultiplier ;
# dehors, la vitesse de chacun et la vitesse fixe Carry.StolenItemWalkSpeed ; aucune détection de l'anti-triche à l'entrée
# ni à la sortie ; Features.SafeZoneSpeed = false : comme avant. Vrais StatsService, CarryService, PvPService,
# AntiCheatService… sur le harnais du banc a36 (autres-bancs/a36z), par la même chaîne que le banc a36 du lanceur
# commun (a198 échelle 1, a180, a172, a158, a153). Les valeurs attendues sont lues dans Config/Balance.
#   bash run.sh [racine du dépôt]   A426_SCENARIOS="zone" : un seul scénario ; VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if ! grep -q "SafeZoneSpeed = " "$ROOT/src/shared/Config/Features.luau" 2>/dev/null; then
	echo "banc a426 : SAUTÉ, a426 pas encore fusionné (0 vérification(s), 0 échec(s))"
	exit 0
fi
exec bash "$B/a198-banc/echelle1.sh" "$H/etape1.sh" repo "$ROOT"
