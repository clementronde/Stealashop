#!/usr/bin/env bash
# a200 (2026-11-15, vague 61) : lanceur du banc a65 sur l'arbre où Training.Treadmill.SideEntryOnly = false (règle
# d'a180 coupée, comme a180-banc/autres-bancs/a65), avec la copie a200 (../a65-core : V3, la séance continue quand le
# tapis est amélioré). Arbre sans Training.Treadmill.SwapGrace (avant a200) : le lanceur d'a180 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
ARG="${ARG%/src}"
if ! grep -q "SwapGrace" "$ARG/src/shared/Config/Training.luau" 2>/dev/null; then
	exec bash "$H/a180-banc/autres-bancs/a65/run.sh" "$ARG"
fi
exec bash "$H/a180-banc/regle-coupee.sh" "$H/a200-banc/autres-bancs/a65-core/run.sh" repo "$ARG"
