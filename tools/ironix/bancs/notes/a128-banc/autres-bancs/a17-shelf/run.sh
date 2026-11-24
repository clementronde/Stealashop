#!/usr/bin/env bash
# Copie d'a128 (vague 39, 2026-11-14, Config/ShelfBoxes.MaxOutlines 25 → 20) : la limite attendue se lit dans
# Config/ShelfBoxes.MaxOutlines (25 avant la fusion, 20 après : bonne sur les deux). Faux Roblox lu sur place (a17-banc/carry).
# Banc hors Studio de a17 : ShelfBoxController (client, L-031). Faux Roblox du banc carry (a11),
# complété dans tests.luau (Heartbeat, DescendantAdded, caméra, Raycast contre des boîtes).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a17 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a17}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$H/../../../a17-banc/carry/fake.luau" # a128 : lu sur place
  (cd "$SRC" && find shared client/Controllers/ShelfBoxController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
