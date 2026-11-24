#!/usr/bin/env bash
# a284 (vague GC3, 23/11) : copie de la copie a159 du banc a08 (même faux Roblox, stubs.luau de la copie a134), section
# « Régénération » réécrite pour Balance.Window.RegenSyncHz = 2 : 1 à 3 WindowHP en 1 s de régénération seule, PV reçus
# au plus 0,5 s en retard, PV pleins toujours envoyés ; les coups restent envoyés au tick suivant (sections d'avant
# inchangées). Lancée par la chaîne du banc a08 (a284-banc/run.sh). Arbre sans RegenSyncHz : « SAUTÉ ».
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-/f/StealAShop/src}"
if ! grep -q "RegenSyncHz = 2," "$SRC/shared/Config/Balance.luau" 2>/dev/null; then
	echo "banc a284 : SAUTÉ, pas de RegenSyncHz : 0 vérification(s), 0 échec(s)"
	exit 0
fi
OUT="$(mktemp -d)/run.luau"
{
  cat "$H/../../../a134-banc/autres-bancs/a08/stubs.luau"
  (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
