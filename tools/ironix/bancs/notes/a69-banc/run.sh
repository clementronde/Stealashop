#!/usr/bin/env bash
# Banc hors Studio d'a69 (2026-11-11, vague 24, retour de Cantin en Play : le vigile doit nous COUPER la
# route, tout de suite et sans à-coups). Vrai GuardService (chaseStep commune : vigiles de jour, de nuit,
# conducteurs), poursuivi par un conducteur du camion. Faux Roblox et préambule (jusqu'à R1) de la copie
# d'a69 du banc a57 (autres-bancs/a57-banc) ; scénarios dans tests.a69.luau :
#   I1 virage derrière le vigile, I2 fuite en ligne droite, I3 zigzag, I4 obstacle, I5 zone safe,
#   I6 cadence des MoveTo, I7 coût.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a69 ; après fusion : /f/StealAShop)
# Avant la fusion d'a69 (GuardService sans interceptPoint) : « SAUTÉ ».
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/autres-bancs/a57-banc"
ROOT="${1:-/f/StealAShop/agents/a69}"
SRC="$ROOT/src"
OUT="$(mktemp -d)/run.luau"
trap 'rm -rf "$(dirname "$OUT")"' EXIT
FILES="shared server/Services/GuardService.luau"
{
  cat "$B/stubs.luau" "$B/stubs.a24.luau" "$B/stubs.a45.luau"
  cat "$B/stub-anticheat.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  tr -d '\r' < "$B/tests.a57.luau" | awk '/^-+ R1 virage/ { exit } { print }'
  cat "$H/tests.a69.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
