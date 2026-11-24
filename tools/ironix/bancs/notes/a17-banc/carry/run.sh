#!/usr/bin/env bash
# Banc hors Studio de DEV-017 (CarryService, CarryController), repris d'a11 et adapté par a17 (BB_Box, L-031).
#   bash run.sh [racine du dépôt]   (défaut : le worktree d'a17 ; après fusion : /f/StealAShop)
# Assemble le faux Roblox, les sources de src/ et les scénarios en un seul fichier, puis l'exécute
# avec le luau de rokit.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a17}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$H/fake.luau"
  (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
