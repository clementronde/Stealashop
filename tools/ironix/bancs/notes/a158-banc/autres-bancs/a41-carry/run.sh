#!/usr/bin/env bash
# a158 (2026-11-14, vague 50, Cantin : le colis porté n'existe plus) : lanceur du banc a41-carry.
# Avant a158 (NPCBoxPayload encore dans Types/Carry) : le banc d'origine, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "NPCBoxPayload = {" "$REPO/src/shared/Types/Carry.luau" 2>/dev/null; then
	exec bash "$H/a41-banc/carry/run.sh" "$@"
fi
# Depuis a158 : banc retiré (soudure et hauteur du colis sur la tête : remplacé par le banc a158, scénario carry).
echo "banc a41-carry : SAUTÉ depuis a158 (le colis porté n'existe plus ; soudure et hauteur du colis sur la tête : remplacé par le banc a158, scénario carry) : 0 vérification(s), 0 échec(s)"
exit 0
