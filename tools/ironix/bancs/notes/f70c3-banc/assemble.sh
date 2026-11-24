#!/usr/bin/env bash
# f70c3 : fichier assemblé d'un scénario, comme a252-banc/assemble.sh (harnais d'a193/a249/a250/a252) ; en plus : le faux
# PathfindingService appelle PATH_F70C3(a, b, params) s'il est posé (params : l'agent, Costs compris ; nil = NoPath),
# Guard/PathAvoid rangé dans le dossier Guard (rangf70c3.luau), correctifs du scénario (pref70c3.luau).
#   bash assemble.sh <src> <tests> <scénario>
set -u
SRC="$1"
TESTS="$2"
NAME="${3:-promo}"
ME="$(cd "$(dirname "$0")" && pwd)"
A249="$ME/../a249-banc"
A250="$ME/../a250-banc"
A252="$ME/../a252-banc"
H="$(cd "$ME/../a193-banc" && pwd)"
A168="$H/../a168-banc"
B146="$H/../a146-banc"
A173="$H/../a174-banc/autres-bancs/a173"
X="$B146/autres-bancs/a36"
FILES="shared server/Services/AntiCheatService.luau server/Services/CarryService.luau server/Services/StatsService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/BatService.luau server/Services/GuardService.luau server/Services/PlotService.luau server/Services/ReturnBaseService.luau server/Services/TrainingService.luau server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/NightCycleService.luau server/Services/Guard client/Controllers/CatchScene"
if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
awk '/^\t\t\tif PATH_FAILS then$/ {
	print "\t\t\tif PATH_F70C3 then"; print "\t\t\t\tlocal w = PATH_F70C3(a, b, p.params)"
	print "\t\t\t\tp.Status = if w then \"Enum.PathStatus.Success\" else \"Enum.PathStatus.NoPath\""
	print "\t\t\t\tp._wps = w or {}"; print "\t\t\t\treturn"; print "\t\t\tend"
	print "\t\t\tif PATH_VIA250 then"; print "\t\t\t\tp.Status = \"Enum.PathStatus.Success\""; print "\t\t\t\tp._wps = PATH_VIA250(a, b)"; print "\t\t\t\treturn"; print "\t\t\tend" } { print }' "$X/stubs.luau"
cat "$B146/overlap-ajout.luau" "$X/ext29.luau" "$X/ext36.luau"
(cd "$SRC" && find $FILES 2>/dev/null -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
cat "$H/../a134-banc/levier-force.luau" "$H/../a134-banc/coups-en-rafale.luau" "$H/../a103-banc/ancien-deroule.luau"
echo "A193_SCENARIO = \"$NAME\""
cat "$A249/pre249.luau" "$A250/pre250.luau" "$A252/pre252.luau" "$ME/pref70c3.luau" "$X/setup.luau" "$A168/commun.luau" "$A173/commun173.luau" "$A252/range252.luau" "$ME/rangf70c3.luau"
awk '/^if A193_SCENARIO == "hold" then/ { exit } { print }' "$H/tests.luau"
awk '/^if S249 == "spring" or S249 == "springoff" then/ { exit } { print }' "$A249/tests.a249.luau"
cat "$TESTS"
