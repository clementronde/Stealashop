#!/usr/bin/env bash
# Banc a400 (vague GC3, audit a272 faille M1, option (a) : collisions entre joueurs coupées) : PlayerCollisionService
# et Config/Features.PlayerCollision, avec un faux Roblox à lui (tests.luau : Players, PhysicsService, arbre
# d'Instances avec DescendantAdded / DescendantRemoving). Groupes posés à l'apparition, sur un outil ajouté, retirés
# quand il part, groupes des autres services gardés, interrupteur à true = rien.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
# Arbre sans PlayerCollisionService : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
NAME="banc a400"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/server/Services/PlayerCollisionService.luau" ]; then
	echo "$NAME : SAUTÉ (pas de PlayerCollisionService dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/a400.luau"
{
	echo "--!nocheck"
	echo "REAL_PRINT = print"
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	for f in shared/Config/DeepFreeze.luau shared/Config/Features.luau server/Services/PlayerCollisionService.luau; do
		printf 'SOURCES["%s"] = [==========[\n' "$f"
		tr -d '\r' < "$SRC/$f"
		printf '\n]==========]\n'
	done
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 1 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
exit $((f > 0))
