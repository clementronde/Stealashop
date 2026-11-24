#!/usr/bin/env bash
# Banc a88, scénario guard (2026-11-11, vague 28) : vrai GuardService, point d'accroche IsHiddenFromNight
# (potion d'invisibilité). Faux Roblox et mise en place (jusqu'à S1) de la copie d'a66 du banc a12, comme
# a66-banc/guard ; scénarios dans tests.guard.luau.
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A12="$H/../../a66-banc/autres-bancs/a12-harness"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
OUT="$(mktemp -d)/run.luau"
trap 'rm -rf "$(dirname "$OUT")"' EXIT
{
  cat "$A12/stubs.luau"
  cat "$A12/../stub-anticheat.luau"
  printf '\nRIG_MODE = "roblox"\n'
  (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  tr -d '\r' < "$A12/tests.luau" | awk '/^-+ S1 apparition$/ { exit } { print }'
  cat "$H/tests.guard.luau"
} > "$OUT"
out=$(timeout 300 "$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1)
printf '%s\n' "$out" | grep -vE "^  ok " || true
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -n "$line" ]; then
  echo "scénario guard : $line"
fi
