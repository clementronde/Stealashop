#!/usr/bin/env bash
# Banc hors Studio de a17 (StoreHeistService, HeistController), repris de a10.
#   bash run.sh [racine src]   (défaut : le worktree a17 ; après fusion : /f/StealAShop/src)
# Assemble les bouchons de a08 (stubs.luau), leurs compléments (ext.luau), les sources et les
# scénarios (tests.luau) en un seul fichier Luau, puis l'exécute avec le luau de rokit.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-/f/StealAShop/agents/a21/src}"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$H/stubs.luau"
  cat "$H/ext.luau"
  (cd "$SRC" && find shared server/Services/StoreHeistService.luau client/Controllers/HeistController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
