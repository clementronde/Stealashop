#!/usr/bin/env bash
# Assemble les bouchons, les sources du worktree et les scénarios en un seul fichier Luau, puis l'exécute.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-/f/StealAShop/agents/a08/src}"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$H/stubs.luau"
  (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
