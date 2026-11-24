#!/usr/bin/env bash
# Banc d'essai hors Studio de GuardService et ChaseController (a12, DEV-018).
#   bash run.sh [racine src]
# Défaut : /f/StealAShop/agents/a12/src ; après fusion : bash run.sh /f/StealAShop/src
# Joue tous les scénarios deux fois : rig de remplacement de Roblox, puis rig en blocs.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-/f/StealAShop/agents/a12/src}"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
for mode in roblox blocks; do
  {
    cat "$H/stubs.luau"
    printf '\nRIG_MODE = "%s"\n' "$mode"
    (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
    cat "$H/tests.luau"
  } > "$OUT"
  "$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
done
