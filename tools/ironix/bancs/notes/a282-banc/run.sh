#!/usr/bin/env bash
# Banc hors Studio d'a282 (vague GC3, 2026-11-23, audit a271 point 4) : SafeZone garde ses zones en cache (signaux
# Added / Removed du tag, AncestryChanged de chaque zone) ; repli sur GetTagged sans signaux. Vrai src/shared/SafeZone.luau
# chargé dans un faux Roblox minimal (tests.luau). Arbre sans a282 : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LABEL="banc a282 (SafeZone en cache)"
if ! grep -q "a282" "$SRC/shared/SafeZone.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, a282 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	echo "VERBOSE = ${VERBOSE:-0} == 1"
	printf 'SAFEZONE_SOURCE = [==========[\n'
	tr -d '\r' < "$SRC/shared/SafeZone.luau"
	printf '\n]==========]\n'
	cat "$H/tests.luau"
} > "$OUT"
out=$("$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
printf '%s\n' "$out" | grep -v "vérification(s)" || true
line=$(printf '%s\n' "$out" | grep -E "SafeZone : [0-9]+ vérification" | tail -1)
if [ -z "$line" ]; then
	echo "$LABEL : 0 vérification(s), 1 échec(s)"
else
	echo "$LABEL : ${line#SafeZone : }"
fi
