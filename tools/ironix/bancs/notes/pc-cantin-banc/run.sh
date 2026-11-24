#!/usr/bin/env bash
# Banc hors Studio de pc-cantin (2026-11-14, Cantin, L-140) : murs invisibles au-dessus des rayons des magasins
# PNJ (ShelfCapService, Config/ShelfCaps). Faux Roblox minimal à lui (fake.luau : Vector3, CFrame, Instances,
# CollectionService) ; magasin d'essai à la géométrie de tools/clement/store_builder.luau (tests.luau).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok et sortie du service
# Arbre sans src/server/Services/ShelfCapService.luau : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LABEL="banc pc-cantin (murs au-dessus des rayons)"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/server/Services/ShelfCapService.luau" ]; then
	echo "$LABEL : SAUTÉ (pas de ShelfCapService dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMPS="$(mktemp -d)"
trap 'rm -rf "$TMPS"' EXIT
OUT="$TMPS/banc.luau"
{
	echo "--!nocheck"
	echo "SOURCES = {}"
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	for f in shared/Config/DeepFreeze.luau shared/Config/Balance.luau shared/Config/ShelfCaps.luau server/Services/ShelfCapService.luau; do
		printf 'SOURCES["%s"] = [==========[\n' "$f"
		tr -d '\r' < "$SRC/$f"
		printf '\n]==========]\n'
	done
	cat "$H/fake.luau" "$H/tests.luau"
	echo 'print("RESULT " .. RESULT_TOTAL .. " " .. RESULT_FAILED)'
} > "$OUT"
RES="$(cd "$TMPS" && "$LUAU" "$OUT" 2>&1)"
echo "$RES" | grep -v "^RESULT "
LINE="$(echo "$RES" | grep "^RESULT " | tail -1)"
if [ -z "$LINE" ]; then
	echo "$LABEL : 1 vérification(s), 1 échec(s) (le banc n'a pas fini)"
	exit 1
fi
set -- $LINE
echo "$LABEL : $2 vérification(s), $3 échec(s)"
[ "$3" = "0" ]
