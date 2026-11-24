#!/usr/bin/env bash
# Banc hors Studio d'a100-police (vague 30, 2026-11-12, L-111) : le policier des témoins dans le vrai GuardService
# (StartDriverChase avec Label, Tired, GiveUpReason ; FindGuardModel ; IsInSafeZone). Faux Roblox et mise en place
# du banc a54-guard, lus sur place (a66-banc/autres-bancs/a54-banc/guard : stubs et début de tests.guard.luau
# jusqu'à « G1 lancement »), suivis de tests.police.luau.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
G="$H/../../../../a66-banc/autres-bancs/a54-banc/guard"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
OUT="$(mktemp -d)/run.luau"
trap 'rm -rf "$(dirname "$OUT")"' EXIT
FILES="shared server/Services/GuardService.luau"
{
  cat "$G/stubs.luau" "$G/stubs.a24.luau" "$G/stubs.a45.luau"
  cat "$G/stub-anticheat.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  awk '/^-+ G1 lancement$/ { exit } { print }' "$G/tests.guard.luau"
  tr -d '\r' < "$H/tests.police.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
