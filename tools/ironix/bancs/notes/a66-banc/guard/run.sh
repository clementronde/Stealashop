#!/usr/bin/env bash
# Banc a66, partie guard (2026-11-11) : vrai GuardService ; faux Roblox et mise en place (jusqu'à S1) de la
# copie d'a66 du banc a12 (../autres-bancs/a12-harness) ; scénarios dans tests.guard.luau.
#   bash run.sh [racine du dépôt]
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
A12="$H/../autres-bancs/a12-harness"
ROOT="${1:-/f/StealAShop/agents/a66}"
SRC="$ROOT/src"
OUT="$(mktemp -d)/run.luau"
trap 'rm -rf "$(dirname "$OUT")"' EXIT
{
  cat "$A12/stubs.luau"
  cat "$H/../autres-bancs/stub-anticheat.luau"
  printf '\nRIG_MODE = "roblox"\n'
  (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  tr -d '\r' < "$A12/tests.luau" | awk '/^-+ S1 apparition$/ { exit } { print }'
  cat "$H/tests.guard.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
