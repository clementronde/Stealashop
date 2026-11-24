#!/usr/bin/env bash
# Banc a409 (GC6, 23/11, MAJ 6) : classements hebdomadaires et casse du siècle.
#   weekly : Config/WeeklyLeaderboard, vrai WeeklyLeaderboardService (faux minimal), calculs purs d'ArmoredVanService ;
#   board  : vrai LeaderboardService (harnais server d'a161) + scénario X : classement ajouté par AddBoard.
# « SAUTÉ » sans WeeklyLeaderboardService.
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a409 (classements hebdomadaires, casse du siècle)"
if [ ! -f "$SRC/server/Services/WeeklyLeaderboardService.luau" ]; then
	echo "$NAME : SAUTÉ, 0 vérification(s), 0 échec(s)"; exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total=0; failed=0
count() {
	local name="$1" out="$2" line c f
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror" || true
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$out" | tail -20; echo "  $name : arrêté avant la fin"; failed=$((failed + 1)); return; fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
}
src() { printf 'local %s = [==========[\n' "$1"; tr -d '\r' < "$SRC/$2"; printf '\n]==========]\n'; }
OUT="$TMP/weekly.luau"
{
	src WL_SOURCE server/Services/WeeklyLeaderboardService.luau
	src WCFG_SOURCE shared/Config/WeeklyLeaderboard.luau
	src AV_SOURCE server/Services/ArmoredVanService.luau
	src AVCFG_SOURCE shared/Config/ArmoredVan.luau
	src FREEZE_SOURCE shared/Config/DeepFreeze.luau
	cat "$H/tests.luau"
} > "$OUT"
count weekly "$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)"
OUT="$TMP/board.luau"
{
	src SOURCE server/Services/LeaderboardService.luau
	src LB_SOURCE shared/Config/Leaderboard.luau
	src FORMAT_SOURCE shared/Format.luau
	src FREEZE_SOURCE shared/Config/DeepFreeze.luau
	tr -d '\r' < "$H/../a161-banc/server.luau" | sed '$d'
	cat "$H/extra-board.luau"
} > "$OUT"
count board "$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)"
echo "$NAME : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
