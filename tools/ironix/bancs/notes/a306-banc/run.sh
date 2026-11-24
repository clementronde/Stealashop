#!/usr/bin/env bash
# Banc a306 (L-284 : « Script timeout » au démarrage du Loader, boutique du joueur pas posée) : vrai Loader du dépôt
# (et celui d'avant, 77b31b3, dans loader-avant.luau) avec un faux ordonnanceur qui compte le temps sans yield par
# reprise comme Roblox (task.spawn dans la reprise de l'appelant, task.defer et task.wait dans une nouvelle).
# Partie R (code d'avant : reproduit le défaut) toujours ; partie N « SAUTÉE » sur un Loader sans task.defer.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a306"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/a306.luau"
HAS_DEFER=false
if grep -q "task.defer(function()" "$SRC/shared/Loader.luau"; then HAS_DEFER=true; fi
HAS_CC=false
if grep -q "a306 (L-284" "$SRC/server/Services/ContractChecker.luau"; then HAS_CC=true; fi
{
	echo "REAL_PRINT = print"
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "HAS_DEFER = $HAS_DEFER"
	echo "HAS_CC_YIELDS = $HAS_CC"
	printf 'LOADER_AVANT = [==========[\n%s\n]==========]\n' "$(tr -d '\r' < "$H/loader-avant.luau")"
	printf 'LOADER_REPO = [==========[\n%s\n]==========]\n' "$(tr -d '\r' < "$SRC/shared/Loader.luau")"
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|SAUTÉE" || true; fi
echo "$line"
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
exit $((f > 0))
