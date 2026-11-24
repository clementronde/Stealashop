#!/usr/bin/env bash
# Copie a159 (2026-11-14, vague 50, L-163) de la copie a134 du banc a08 : porte d'une parcelle à PvP.DoorHits (40)
# coups, un coup = 1 quelle que soit la force (section « Parcelles » et « Parcelle cassée » : 40 au lieu de 50,
# casse en coups au lieu d'un seul coup à 1e7 de force). stubs.luau lu dans la copie a134. Arbre sans PvP.DoorHits :
# lance la copie a134 (bonne avant et après la fusion).
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-/f/StealAShop/src}"
if ! grep -q "DoorHits = " "$SRC/shared/Config/PvP.luau" 2>/dev/null; then exec bash "$H/../../../a134-banc/autres-bancs/a08/run.sh" "$@"; fi
OUT="$(mktemp -d)/run.luau"
{
  cat "$H/../../../a134-banc/autres-bancs/a08/stubs.luau"
  (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
