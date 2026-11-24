#!/usr/bin/env bash
# a227 (vague 69, L-175) : banc a32 comme la copie fusion58 (f58-banc/autres-bancs/a32), mais sur la copie a227 (plus de Beam V0).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
# Arbre sans a227 (Beam V0 encore dans TheftAlertController) : la copie fusion58 telle quelle.
if grep -q "makeArrowV0" "${1:-/f/StealAShop}/src/client/Controllers/TheftAlertController.luau" 2>/dev/null; then exec bash "$N/f58-banc/autres-bancs/a32/run.sh" "$@"; fi
exec bash "$N/a212-banc/corrige.sh" a32 "$N/a227-banc/autres-bancs/a32/run-a198.sh" "$@"
