#!/usr/bin/env bash
# Banc a410 (vague GC6, 23/11, MAJ 7) : colonnes de mutations de l'index (IndexMutations, IndexService) et notifications
# Roblox (NotificationService). « SAUTÉ » sur un arbre sans Shared/IndexMutations (avant a410).
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok ; A410_LOG=<fichier> : sortie complète
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a410"
if [ ! -f "$SRC/shared/IndexMutations.luau" ]; then
	echo "$NAME : SAUTÉ, pas de colonnes de mutations (avant a410) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/a410.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	(cd "$SRC" && find shared server/Services -maxdepth 2 -name "*.luau" -print0 | xargs -0 awk -f "$H/assemble.awk")
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
if [ -n "${A410_LOG:-}" ]; then printf '%s\n' "$out" > "$A410_LOG"; fi
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
exit $((f > 0))
