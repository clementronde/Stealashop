#!/usr/bin/env bash
# Banc hors Studio de pc-l140 (2026-11-14, Cantin, L-140) : grimpe coupée dans les magasins PNJ
# (StoreClimbController, client ; Config/ShelfCaps). Reprend le faux Roblox de pc-cantin-banc/fake.luau, plus
# fake-client.luau (Players.LocalPlayer, Humanoid, Enum, task, WaitForChild).
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
# Arbre sans src/client/Controllers/StoreClimbController.luau : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LABEL="banc pc-l140 (grimpe dans les magasins)"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/client/Controllers/StoreClimbController.luau" ]; then
	echo "$LABEL : SAUTÉ (pas de StoreClimbController dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMPS="$(mktemp -d)"
trap 'rm -rf "$TMPS"' EXIT
OUT="$TMPS/banc.luau"
{
	echo "--!nocheck"
	echo "SOURCES = {}"
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	for f in shared/Config/DeepFreeze.luau shared/Config/Balance.luau shared/Config/ShelfCaps.luau server/Services/ShelfCapService.luau client/Controllers/StoreClimbController.luau; do
		printf 'SOURCES["%s"] = [==========[\n' "$f"
		tr -d '\r' < "$SRC/$f"
		printf '\n]==========]\n'
	done
	cat "$H/../pc-cantin-banc/fake.luau" "$H/fake-client.luau" "$H/tests.luau"
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
