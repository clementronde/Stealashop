#!/usr/bin/env bash
# Banc hors Studio d'a277 (vague GC2, L-249, L-238 a) : Sprint du vigile (server/Services/Guard/Gait, Config/Chase.Sprint,
# Contract/Animations). Vrais AnimPlayer, Animations, Chase, Balance, DeepFreeze et Gait sur un petit faux Roblox ; les
# vraies fonctions gaitSpeed, playGait et setWalkSpeed (et leurs constantes) tirées de GuardService.
#   bash run.sh [racine du dépôt]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! [ -f "$SRC/server/Services/Guard/Gait.luau" ]; then
	echo "banc a277 : SAUTÉ, a277 pas encore fusionné (0 vérification(s), 0 échec(s))"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/a277.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	for f in shared/Config/Chase.luau shared/Config/DeepFreeze.luau shared/Config/Balance.luau shared/Anim/AnimPlayer.luau shared/Contract/Animations.luau server/Services/Guard/Gait.luau; do
		printf 'SOURCES["%s"] = [==========[\n' "$f"
		tr -d '\r' < "$SRC/$f"
		printf '\n]==========]\n'
	done
	# Constantes et fonctions de pas de GuardService, telles quelles.
	printf 'GUARD_GAIT = [==========[\n'
	tr -d '\r' < "$SRC/server/Services/GuardService.luau" | awk '
		/^local GAIT_REFERENCE/ { on = 1 }
		on { print }
		/^local GAIT_SPEED_MAX/ { on = 0 }
		/^local function gaitSpeed/ { fn = 1 }
		/^local function setState/ { fn = 0 }
		fn { print }'
	printf '\n]==========]\n'
	tr -d '\r' < "$H/tests.a277.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1 || true)
if [ "${VERBOSE:-}" = "1" ]; then
	printf '%s\n' "$out"
else
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|rror" || true
fi
line=$(printf '%s\n' "$out" | grep -E "^banc a277 : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -20
	echo "banc a277 : arrêté avant la fin (0 vérification(s), 1 échec(s))"
	exit 1
fi
echo "$line"
