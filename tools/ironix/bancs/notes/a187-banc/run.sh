#!/usr/bin/env bash
# Banc hors Studio d'a187 (2026-11-15, vague 58, L-177) : l'écran de chargement de ReplicatedFirst
# (src/first/LoadingScreen.local.luau et LoadingConfig.luau, vrais), sur un faux Roblox à lui (tests.luau) :
# barre de 0 à 100 % qui suit le chargement, astuces, Skip à 5 s, fermeture à 100 % et à 20 s, fondu, sans UI_Loading.
# « SAUTÉ » sur un arbre sans src/first (avant a187).
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a187"
if [ ! -f "$SRC/first/LoadingScreen.local.luau" ]; then
	echo "$NAME : SAUTÉ, pas de src/first/LoadingScreen.local.luau (a187 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="first/LoadingScreen.local.luau first/LoadingConfig.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec"
