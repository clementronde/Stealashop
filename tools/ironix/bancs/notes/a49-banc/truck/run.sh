#!/usr/bin/env bash
# Scénario truck du banc a49 (DEV-131) : faux Roblox et mise en place du banc a27 (copie d'a46,
# ../../a46-banc/autres-bancs/a27-banc : stubs, bouchon d'AntiCheatService, setup), puis tests.truck.luau.
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A="$H/../../a46-banc/autres-bancs/a27-banc"
ROOT="${1:-/f/StealAShop/agents/a49}"
SRC="$ROOT/src"
FILES="shared server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/UnboxService.luau server/Services/ContractChecker.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.truck.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A/stubs.luau" "$A/../../../a36-banc/autres-bancs/stub-anticheat.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$A/setup.luau" "$H/tests.truck.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1
