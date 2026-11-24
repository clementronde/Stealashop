#!/usr/bin/env bash
# a158 (2026-11-14, vague 50, Cantin : le colis porté n'existe plus) : lanceur du banc a12.
# Avant a158 (NPCBoxPayload encore dans Types/Carry) : le banc d'origine, tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
# a171 (2026-11-15, vague 52) : arbre avec a165 (« Caught! » seul en zone 1) : la copie a165 du banc, qui relance ce
# lanceur avec un faux luau.exe ; A171_A12_A165 empêche la boucle (la copie revient ici, qui fait alors le travail d a158).
if [ -z "${A171_A12_A165:-}" ] && grep -q 'else "Caught!" -- vague 51' "$REPO/src/server/Services/GuardService.luau" 2>/dev/null; then
	A171_A12_A165=1 exec bash "$H/a165-banc/autres-bancs/a12/run.sh" "$@"
fi
if grep -q "NPCBoxPayload = {" "$REPO/src/shared/Types/Carry.luau" 2>/dev/null; then
	exec bash "$H/a153-banc/autres-bancs/a12/run.sh" "$@"
fi
# Depuis a158 : ../../corrige.sh (corrections : patches/commun.sed, patches/a12.sed et patches/a12.pre.luau s'ils existent).
exec bash "$H/a158-banc/corrige.sh" a12 bash "$H/a153-banc/regle-coupee.sh" "$H/a134-banc/autres-bancs/a12/run.sh" src "$REPO"
