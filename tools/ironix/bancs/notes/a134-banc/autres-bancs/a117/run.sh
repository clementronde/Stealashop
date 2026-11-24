#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : bandeau de zone : Speed du panneau (SpeedRequired), Damage v2.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a117-banc/run.sh" "$@"; fi
# Banc hors Studio d'a117 (vague 34, 2026-11-13, liaison L-127 points 1, 2 et 3).
#   banner  : vrai ZoneBannerController sur le faux Roblox de la copie a101 du banc a42 (a101-banc/autres-bancs/a42-banc) :
#             Advice.Speed et Advice.Damage = le chiffre seul (Format.short), zones 1 à 6 (tests.banner.luau).
#   claim   : serveur, vrai IndexService sur la copie a117 du banc a55 (autres-bancs/a55-banc, scénario tests.claim.luau) :
#             ClaimIndexReward(zone) et sans zone (toutes), jamais deux fois, refus, IndexClaimed, primes d'avant gardées.
#   index   : serveur + client, vrais IndexService, IndexController, RailAlertController, RewardsController et
#             Shared/AlertBadge sur la copie a117 du banc Index v3 (autres-bancs/a40-v3, scénario tests.a117index.luau) :
#             ClaimButton et ClaimAllButton (refus, réussite T.33), chaque pastille « ! » allumée puis éteinte, Pulse qui bat.
# « SAUTÉ » sans ClaimIndexReward (avant la fusion d'a117).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
NOTES="$(cd "$H/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a117 (bandeau, Claim All, pastilles)"
if ! grep -q '"ClaimIndexReward"' "$SRC/shared/Net/Definitions.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (pas de remote ClaimIndexReward) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
total=0; failed=0
add() { # $1 = ligne « … : N vérification(s), F échec(s) » ou « N contrôles, F raté(s) »
	if [ -z "$1" ]; then failed=$((failed + 1)); return; fi
	total=$((total + $(printf '%s' "$1" | sed -E 's/.*[^0-9]([0-9]+) (vérification|contrôle).*/\1/')))
	failed=$((failed + $(printf '%s' "$1" | sed -E 's/.*, ([0-9]+) (échec|raté).*/\1/')))
}
# banner
B="$NOTES/a101-banc/autres-bancs/a42-banc"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FILES="shared client/Controllers/UI client/Controllers/ZoneGateController.luau client/Controllers/ZoneBannerController.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$B/stubs.luau"
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	echo 'CLIENT_LIST = { "ZoneGateController", "ZoneBannerController" }'
	echo 'STORE_INFO_UI = false'
	cat "$B/setup.luau"
	tr -d '\r' < "$H/tests.banner.luau"
} > "$TMP/run.banner.luau"
out=$("$LUAU" "$(cygpath -w "$TMP/run.banner.luau")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
[ -z "$line" ] && printf '%s\n' "$out" | tail -15
echo "  banner : ${line:-arrêté avant la fin}"
add "$line"
# claim (serveur)
out=$(bash "$H/../../../a117-banc/autres-bancs/a55-banc/run.sh" "$ROOT" claim 2>&1)
printf '%s\n' "$out" | grep -vE "vérification\(s\)|contrôles" || true
line=$(printf '%s\n' "$out" | grep -E "^  claim : [0-9]+ contrôles" | tail -1)
echo "  claim : ${line:-arrêté avant la fin}"
add "$line"
# index (serveur + client)
out=$(bash "$H/../../../a117-banc/autres-bancs/a40-v3/run.sh" "$ROOT" a117index 2>&1)
printf '%s\n' "$out" | grep -vE "vérification\(s\)|contrôles" || true
line=$(printf '%s\n' "$out" | grep -E "^  a117index : [0-9]+ contrôles" | tail -1)
echo "  index : ${line:-arrêté avant la fin}"
add "$line"
echo "$LABEL : $total vérification(s), $failed échec(s)"
exit $((failed > 0))
