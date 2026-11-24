#!/usr/bin/env bash
# Banc hors Studio d'a101 (vague 30, 2026-11-12, liaison L-110) : bandeau d'entrée de zone UI_ZoneBanner.
# Vrais : ZoneGateController (zone du joueur local, passage d'arche), ZoneBannerController (textes, couleurs,
# fondu), Config/Zones (City), Config/UiMotion.ZoneBanner, AdvicePanel, Contract. Faux Roblox et carte : ceux de la
# copie a101 du banc a42 (autres-bancs/a42-banc : stubs.luau, setup.luau avec buildZoneBannerUi).
# Scénarios : banner (passages, textes, couleurs, fondu, écran refait), stream (une seule arche connue, arche qui
# arrive par le streaming, écran absent, élément manquant). « SAUTÉ » sans ZoneBannerController.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/autres-bancs/a42-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a101"
if [ ! -f "$SRC/client/Controllers/ZoneBannerController.luau" ]; then
	echo "$NAME (bandeau de zone) : SAUTÉ, pas de ZoneBannerController (a101 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/ZoneGateController.luau client/Controllers/ZoneBannerController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in banner stream; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B/stubs.luau"
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
echo "$NAME (bandeau de zone) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))
