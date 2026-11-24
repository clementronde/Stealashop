#!/usr/bin/env bash
# Banc hors Studio d'a68 (vague 23, liaison L-095, note de Clément ui-feel2-horsligne-poursuite-barre.md, point
# « Poursuite ») : ChaseFeelController (sons au départ et arrêt à la fin, bulle BB_GuardShout créée puis
# détruite, LeftRail et UI_Hotbar cachés puis remis dans leur état d'origine) et départ de MUS_Chase à
# Config/ChaseFeel.MusicStartAt (MusicController). Mise en place : setup.luau de la copie d'a42
# (autres-bancs/a42-banc) ; faux Roblox : sa copie stubs.luau, avec le service Debris (MarkerSounds).
# Avant la fusion (arbre sans ChaseFeelController) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (feel keep missing)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/autres-bancs/a42-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
if [ ! -f "$SRC/client/Controllers/ChaseFeelController.luau" ]; then
	echo "banc a68 (ambiance de la poursuite) : SAUTÉ (pas de ChaseFeelController dans $ROOT), 0 vérification(s), 0 échec(s)"
	exit 0
fi
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-feel keep missing}"
FILES="shared client/Controllers/UI client/Controllers/ChaseFeelController.luau client/Controllers/ChaseController.luau client/Controllers/MusicController.luau client/Controllers/NotifyController.luau client/Controllers/ZoneGateController.luau client/Controllers/StoreInfoController.luau client/Controllers/TruckController.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/ContractChecker.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau"
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$B/setup.luau"
		cat "$H/common.luau"
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a68 (ambiance de la poursuite) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
