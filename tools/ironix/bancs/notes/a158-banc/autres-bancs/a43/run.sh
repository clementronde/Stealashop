#!/usr/bin/env bash
# a158 (2026-11-14, vague 50, Cantin : le colis porté n'existe plus) : lanceur du banc a43.
# Avant a158 (NPCBoxPayload encore dans Types/Carry) : le banc d'origine, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "NPCBoxPayload = {" "$REPO/src/shared/Types/Carry.luau" 2>/dev/null; then
	exec bash "$H/a51-banc/autres-bancs/a43-banc/run.sh" "$@"
fi
# Depuis a158 : banc retiré (écran d'ouverture en base, roulette et révélation : l'ouverture en base est retirée côté serveur).
echo "banc a43 : SAUTÉ depuis a158 (le colis porté n'existe plus ; écran d'ouverture en base, roulette et révélation : l'ouverture en base est retirée côté serveur) : 0 vérification(s), 0 échec(s)"
exit 0
