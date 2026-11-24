#!/usr/bin/env bash
# Banc a157, partie window (2026-11-14, vague 49, Cantin : en zone safe, plus aucun événement des magasins PNJ) :
# vrai WindowService et vrai Shared/SafeZone, faux Roblox de la copie a44 du banc a16 (comme le banc a70, partie
# window). Scénarios dans tests.window.luau. « SAUTÉ » sans Shared/SafeZone.
#   bash run.sh [racine du dépôt]
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
A16="$H/../../a44-banc/autres-bancs/a16-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
if [ ! -f "$SRC/shared/SafeZone.luau" ]; then
	echo "a157 window SAUTÉ : pas de Shared/SafeZone"
	echo "0 vérification(s), 0 échec(s)"
	exit 0
fi
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
