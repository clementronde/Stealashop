#!/usr/bin/env bash
# Banc hors Studio d'a54-guard (2026-11-10, vague 20, L-083 point 3) : GuardService.StartDriverChase, la
# poursuite des conducteurs du camion (lancement, vitesse, capture, colis perdu, abandons, fondu).
# Vrais : GuardService, Shared (Config, Contract, Net, Anim, Format). Bouchons : CarryService,
# StatsService, AntiCheatService. Faux Roblox : celui du banc a45 (stubs.luau, stubs.a24.luau,
# stubs.a45.luau, stub-anticheat.luau, copiés tels quels).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a54 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a54}"
SRC="$ROOT/src"
OUT="$(mktemp -d)/run.luau"
trap 'rm -rf "$(dirname "$OUT")"' EXIT
FILES="shared server/Services/GuardService.luau"
{
  cat "$H/stubs.luau" "$H/stubs.a24.luau" "$H/stubs.a45.luau"
  cat "$H/stub-anticheat.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.guard.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
