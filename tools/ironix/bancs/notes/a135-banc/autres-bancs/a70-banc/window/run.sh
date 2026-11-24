#!/usr/bin/env bash
# Banc a70, partie window (2026-11-11, vague 24) : vrai WindowService, WindowService.AddHitGate.
# Faux Roblox de la copie a44 du banc a16 (stubs.luau, ../../ext-carve.luau) et en-tête de ses tests
# (faux Net, faux ToolService, arbre des modules : jusqu'à la ligne « monde ») ; scénarios dans
# tests.window.luau.
#   bash run.sh [racine du dépôt]
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
A16="$H/../../../../a44-banc/autres-bancs/a16-banc" # a135 : lu sur place
ROOT="${1:-/f/StealAShop/agents/a70}"
SRC="$ROOT/src"
OUT="$(mktemp -d)/run.luau"
trap 'rm -rf "$(dirname "$OUT")"' EXIT
{
  cat "$A16/stubs.luau"
  cat "$A16/../../ext-carve.luau"
  (cd "$SRC" && { find shared -name '*.luau'; echo server/Services/WindowService.luau; } | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  tr -d '\r' < "$A16/tests.luau" | awk '/^-+ monde$/ { exit } { print }'
  cat "$H/tests.window.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
