#!/usr/bin/env bash
# Copie a237 (vague 71) du banc a120 (a120-banc/run.sh, tests lus là-bas) : faux Roblox complété par a237-banc/ext237.luau
# (GetPropertyChangedSignal, ajout pur). Arbre sans a237 (ZoneBannerController sans « a237 ») : le lanceur d origine.
ARG="${1:-/f/StealAShop}"
if ! grep -q "a237" "${ARG%/src}/src/client/Controllers/ZoneBannerController.luau" 2>/dev/null; then
	exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a120-banc/run.sh" "$@"
fi
EXT="$(cd "$(dirname "$0")/../.." && pwd)/ext237.luau"
# Banc hors Studio d'a120 (vague 35, 2026-11-13, décisions de Cantin) : le bandeau de zone UI_ZoneBanner ne passe
# jamais par-dessus RUN!, l'alerte de vol ni le chrono HEIST. Vrais : ZoneGateController, ZoneBannerController ;
# ChaseController, HudController et TheftAlertController sont des bouchons (IsChased, IsHeistTimerShown, IsShown)
# posés par tests.rules.luau. Faux Roblox et carte : copie a101 du banc a42 (a101-banc/autres-bancs/a42-banc).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")/../../../a120-banc" && pwd)"
B="$H/../a101-banc/autres-bancs/a42-banc" # faux Roblox de la copie a101 du banc a42
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a120"
if ! grep -q "function TheftAlertController.IsShown" "$SRC/client/Controllers/TheftAlertController.luau" 2>/dev/null; then
	echo "$NAME (bandeau de zone qui cède) : SAUTÉ, pas de TheftAlertController.IsShown (a120 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/ZoneGateController.luau client/Controllers/ZoneBannerController.luau client/Controllers/TheftAlertController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in rules; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B/stubs.luau"
		cat "$EXT" # a237
		sources
		echo 'CLIENT_LIST = { "ZoneGateController", "ZoneBannerController" }'
		echo 'STORE_INFO_UI = false'
		cat "$B/setup.luau"
		tr -d '\r' < "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$NAME (bandeau de zone qui cède) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
