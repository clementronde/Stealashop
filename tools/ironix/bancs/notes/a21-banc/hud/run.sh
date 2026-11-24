#!/usr/bin/env bash
# Banc hors Studio de a21, côté client : HudController (NightCountdown, ReturnBaseButton) et
# SkyController (ciel, lumière, lampadaires). Faux Roblox : celui de a15 (écrans, boutons), complété
# (Color3.Lerp, Lighting, lumières). HeistController et ChaseController : bouchons.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a21 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a21}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared client/Controllers/HudController.luau client/Controllers/SkyController.luau"
{
  cat "$H/stubs.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
