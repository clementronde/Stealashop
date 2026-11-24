#!/usr/bin/env bash
# a249 : fichier assemblé d'un scénario, sur le harnais d'a193/a198/a224 (morceaux lus sur place, comme
# a224-banc/assemble-chase.sh) ; pre249.luau et tests.a249.luau à moi.
#   bash assemble.sh <src> <tests> <scénario>
set -u
SRC="$1"
TESTS="$2"
NAME="${3:-spring}"
ME="$(cd "$(dirname "$0")" && pwd)"
H="$(cd "$ME/../a193-banc" && pwd)"
A168="$H/../a168-banc"
B146="$H/../a146-banc"
A173="$H/../a174-banc/autres-bancs/a173"
X="$B146/autres-bancs/a36"
FILES="shared server/Services/AntiCheatService.luau server/Services/CarryService.luau server/Services/StatsService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/BatService.luau server/Services/GuardService.luau server/Services/PlotService.luau server/Services/ReturnBaseService.luau server/Services/TrainingService.luau server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/NightCycleService.luau"
if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
cat "$X/stubs.luau" "$B146/overlap-ajout.luau" "$X/ext29.luau" "$X/ext36.luau"
(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
cat "$H/../a134-banc/levier-force.luau" "$H/../a134-banc/coups-en-rafale.luau" "$H/../a103-banc/ancien-deroule.luau"
echo "A193_SCENARIO = \"$NAME\""
cat "$ME/pre249.luau" "$X/setup.luau" "$A168/commun.luau" "$A173/commun173.luau"
awk '/^if A193_SCENARIO == "hold" then/ { exit } { print }' "$H/tests.luau"
cat "$TESTS"
