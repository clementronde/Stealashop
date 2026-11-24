#!/usr/bin/env bash
# a294 (21/11) : le banc a285 (a285-banc/run.sh) corrigé par ../../patches/a285.sed (Disco Ball Épique, chances validées
# par Cantin, ProcessReceipt des seuls lots de la caisse boutique coupée). Arbre sans a294 (pas de RobuxCrateDev) : tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'RobuxCrateDev = ' "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a285-banc/run.sh" "$@"
fi
exec bash "$H/a294-banc/corrige.sh" a285 bash "$H/a285-banc/run.sh" "$@"
