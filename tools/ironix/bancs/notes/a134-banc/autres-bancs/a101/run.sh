#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : bandeau de zone : Speed du panneau (0 à 3B) comparée à la Speed affichée, Damage v2 ; faux arbre : levier-force.luau et coups-en-rafale.luau.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a117-banc/autres-bancs/a101-banc/run.sh" "$@"; fi
if ! grep -q '"ClaimIndexReward"' "${1:-/f/StealAShop}/src/shared/Net/Definitions.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a101-banc/run.sh" "$@"; fi # a117 : arbre sans a117 → le banc d'origine
# Copie a117 (vague 34, 2026-11-13, L-127 point 1) : Advice.Speed et Advice.Damage = le chiffre seul (« 16 », « 40K ») : B9, B23, B30.
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
B="$(cd "$H/../../../a117-banc/.." && pwd)/a101-banc/autres-bancs/a42-banc" # copie a117 : faux Roblox de la copie a101 du banc a42
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
		cat "$H/../../levier-force.luau" # a134 : faux arbre, voir ce fichier
		cat "$H/../../coups-en-rafale.luau" # a134 : faux arbre, voir ce fichier
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
