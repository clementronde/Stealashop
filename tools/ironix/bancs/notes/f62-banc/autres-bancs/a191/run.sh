#!/usr/bin/env bash
# fusion62 (vague 66) : a191 avec les deux corrections, a218 (NewAuras = true : anciennes auras remises) par-dessus la copie
# a219 (réserve qui prend tout objet libre). NewAuras pas à true : la copie a219 seule.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q '^[[:space:]]*NewAuras = true,' "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a219-banc/autres-bancs/a191-f57.sh" "$@"
fi
exec bash "$H/a218-banc/corrige.sh" anciennes-auras bash "$H/a219-banc/autres-bancs/a191-f57.sh" "$@"
