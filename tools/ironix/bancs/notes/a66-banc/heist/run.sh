#!/usr/bin/env bash
# Banc a66, partie heist (2026-11-11) : vrai StoreHeistService et vrai StoreLockController ; faux Roblox et
# mise en place (jusqu'au démarrage) de la copie d'a66 du banc a17-heist (../autres-bancs/a17-heist, avec
# son bouchon de GuardService) ; scénarios dans tests.heist.luau.
#   bash run.sh [racine du dépôt]
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
A17="$H/../autres-bancs/a17-heist"
ROOT="${1:-/f/StealAShop/agents/a66}"
SRC="$ROOT/src"
OUT="$(mktemp -d)/run.luau"
trap 'rm -rf "$(dirname "$OUT")"' EXIT
{
  cat "$A17/stubs.luau"
  cat "$A17/ext.luau"
  cat "$H/../autres-bancs/stub-anticheat.luau"
  printf '\nBASEPART_PROPS.LocalTransparencyModifier = 0 -- a66 : rideau caché chez le voleur\n'
  (cd "$SRC" && find shared server/Services/StoreHeistService.luau client/Controllers/HeistController.luau client/Controllers/StoreLockController.luau -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  tr -d '\r' < "$A17/tests.luau" | awk '/^-+ démarrage$/ { exit } { print }'
  cat "$H/tests.heist.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
