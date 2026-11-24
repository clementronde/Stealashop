#!/usr/bin/env bash
# a158 (2026-11-14, vague 50, Cantin : le colis porté n'existe plus) : lanceur du banc a31.
# Avant a158 (NPCBoxPayload encore dans Types/Carry) : le banc d'origine, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "NPCBoxPayload = {" "$REPO/src/shared/Types/Carry.luau" 2>/dev/null; then
	exec bash "$H/a128-banc/autres-bancs/a31-banc/run.sh" "$@"
fi
# Depuis a158 : ../../corrige.sh (corrections : patches/commun.sed, patches/a31.sed et patches/a31.pre.luau s'ils existent).
exec bash "$H/a158-banc/corrige.sh" a31 bash "$H/a128-banc/autres-bancs/a31-banc/run.sh" "$ARG" 
