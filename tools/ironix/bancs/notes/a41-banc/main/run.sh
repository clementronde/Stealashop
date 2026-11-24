#!/usr/bin/env bash
# Banc hors Studio d'a41 (2026-11-08, liaison L-071, points 3 et 5) : TrainingService (tapis sans
# invite, banc), GuardService et ChaseController (coup du vigile au marqueur Impact de Catch).
# Faux Roblox : stubs.luau (copie de celui d'a12, complétée par a41) et stub-anticheat.luau (a36).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a41 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a41}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$H/stubs.luau"
  cat "$H/stub-anticheat.luau"
  (cd "$SRC" && find shared server/Services/GuardService.luau server/Services/TrainingService.luau client/Controllers/ChaseController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
