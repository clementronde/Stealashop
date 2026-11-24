#!/usr/bin/env bash
# a158 (2026-11-14, vague 50, Cantin : le colis porté n'existe plus) : lanceur du banc a55.
# Avant a158 (NPCBoxPayload encore dans Types/Carry) : le banc d'origine, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "NPCBoxPayload = {" "$REPO/src/shared/Types/Carry.luau" 2>/dev/null; then
	exec bash "$H/a117-banc/autres-bancs/a55-banc/run.sh" "$@"
fi
# Depuis a158 : ../../corrige.sh (corrections : patches/commun.sed, patches/a55.sed et patches/a55.pre.luau s'ils existent).
# Scénarios gardés : rewardoff (les autres vérifiaient le colis porté, posé au sol ou ouvert en base).
exec bash "$H/a158-banc/corrige.sh" a55 bash "$H/a117-banc/autres-bancs/a55-banc/run.sh" "$ARG" rewardoff
