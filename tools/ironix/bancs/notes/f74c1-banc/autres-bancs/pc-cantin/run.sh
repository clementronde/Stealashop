#!/usr/bin/env bash
# Copie f74c1 (2026-11-19, T-061 : meuble haut et étroit coiffé, Config/ShelfCaps.FurnitureNarrow*) du banc
# pc-cantin : tests.luau à elle (S5 : comtoise coiffée, panneau bas et étroit, montant fin et linteau hors de
# portée libres), faux Roblox de pc-cantin-banc/fake.luau lu sur place.
# Arbre sans FurnitureNarrowMinTop (avant f74c1) : relance le banc pc-cantin d'origine.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok et sortie du service
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ORIG="$(cd "$H/../../../pc-cantin-banc" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
if [ ! -f "$SRC/shared/Config/ShelfCaps.luau" ] || ! grep -q "FurnitureNarrowMinTop" "$SRC/shared/Config/ShelfCaps.luau"; then
	exec bash "$ORIG/run.sh" "$ROOT"
fi
LABEL="banc pc-cantin, copie f74c1 (murs au-dessus des rayons et des meubles hauts et étroits)"
LUAU="$HOME/.rokit/bin/luau.exe"
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
	cat "$ORIG/fake.luau" "$H/tests.luau"
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
