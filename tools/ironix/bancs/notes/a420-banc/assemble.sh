#!/usr/bin/env bash
# a420 (24/11) : copie d'a416-banc/assemble.sh, plus pre420.luau (scénarios « …sans ») et A420_TRACE (trace image par image).
# a416 : fichier assemblé d'un scénario, comme f70c3-banc/assemble.sh (harnais d'a193/a249/a250/a252/f70c3, morceaux lus
# sur place). En plus, ajouts purs au faux Roblox : PhysicsService:CollisionGroupsAreCollidable (table COLLIDABLE du
# faux), Guard/ClientView rangé dans le dossier Guard (rang416.luau) ; correctifs du scénario : pre416.luau (à la place
# de pref70c3.luau, qui remet l'approche lente d'a224 hors de son scénario « proche »).
#   bash assemble.sh <src> <tests> <scénario>
set -u
SRC="$1"
TESTS="$2"
NAME="${3:-zones}"
ME="$(cd "$(dirname "$0")" && pwd)"
A249="$ME/../a249-banc"
A250="$ME/../a250-banc"
A252="$ME/../a252-banc"
F70C3="$ME/../f70c3-banc"
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
	print "\t\t\tif PATH_VIA250 then"; print "\t\t\t\tp.Status = \"Enum.PathStatus.Success\""; print "\t\t\t\tp._wps = PATH_VIA250(a, b)"; print "\t\t\t\treturn"; print "\t\t\tend" }
	{ print }
	/^local PhysicsService = \{$/ {
	print "\tCollisionGroupsAreCollidable = function(_, a, b) -- a416 : ajout pur"
	print "\t\tassert(COLLISION_GROUPS[a] and COLLISION_GROUPS[b], \"groupe de collision non enregistré (faux Roblox) : \" .. tostring(a) .. \", \" .. tostring(b))"
	print "\t\treturn COLLIDABLE[a .. \"|\" .. b] ~= false"; print "\tend," }' "$X/stubs.luau"
cat "$B146/overlap-ajout.luau" "$X/ext29.luau" "$X/ext36.luau"
(cd "$SRC" && find $FILES 2>/dev/null -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
cat "$H/../a134-banc/levier-force.luau" "$H/../a134-banc/coups-en-rafale.luau" "$H/../a103-banc/ancien-deroule.luau"
echo "A193_SCENARIO = \"$NAME\""
echo "A420_TRACE = ${A420_TRACE:-false}"
cat "$A249/pre249.luau" "$A250/pre250.luau" "$A252/pre252.luau" "$ME/pre416.luau" "$ME/pre420.luau" "$X/setup.luau" "$A168/commun.luau" "$A173/commun173.luau" "$A252/range252.luau" "$F70C3/rangf70c3.luau" "$ME/rang416.luau"
awk '/^if A193_SCENARIO == "hold" then/ { exit } { print }' "$H/tests.luau"

cat "$TESTS"
