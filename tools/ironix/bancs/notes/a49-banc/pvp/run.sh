#!/usr/bin/env bash
# Scénario pvp du banc a49 (DEV-131) : faux Roblox et mise en place du banc a29 (copie d'a36,
# ../../a36-banc/autres-bancs/a29-banc : stubs, ext29, bouchon d'AntiCheatService, setup), puis
# tests.pvp.luau. Vrais PvPService, DisplayService, PlotService, WindowService, CarryService.
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A="$H/../../a36-banc/autres-bancs/a29-banc"
ROOT="${1:-/f/StealAShop/agents/a49}"
SRC="$ROOT/src"
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/PvPController.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.pvp.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A/stubs.luau" "$A/ext29.luau" "$A/../stub-anticheat.luau" "$H/../ext49.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$A/setup.luau" "$H/tests.pvp.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1
