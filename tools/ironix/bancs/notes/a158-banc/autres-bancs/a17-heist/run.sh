#!/usr/bin/env bash
# a158 (2026-11-14, vague 50, Cantin : le colis porté n'existe plus) : lanceur du banc a17-heist.
# Avant a158 (NPCBoxPayload encore dans Types/Carry) : le banc d'origine, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "NPCBoxPayload = {" "$REPO/src/shared/Types/Carry.luau" 2>/dev/null; then
	exec bash "$H/a135-banc/autres-bancs/a17-heist/run.sh" "$@"
fi
# Depuis a158 : banc retiré (prise d'un colis fermé sur le rayon, ancien déroulé : l'ouverture sur le rayon est vérifiée par les bancs a103, a109, a110 et a116).
echo "banc a17-heist : SAUTÉ depuis a158 (le colis porté n'existe plus ; prise d'un colis fermé sur le rayon, ancien déroulé : l'ouverture sur le rayon est vérifiée par les bancs a103, a109, a110 et a116) : 0 vérification(s), 0 échec(s)"
exit 0
