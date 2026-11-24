#!/usr/bin/env bash
# Banc d'essai hors Studio de a13 (DEV-019 : UnboxService, UnboxController).
# Assemble les bouchons, les vraies sources partagées (Config, Contract, Net, Types) et les deux
# fichiers de a13, puis les scénarios, en un seul fichier Luau exécuté par le luau de rokit.
# DataService, PlotService, CarryService, DisplayService et AnimationController y sont des bouchons.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop/agents/a13 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a13}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  cat "$H/stubs.luau"
  (cd "$SRC" && find shared server/Services/UnboxService.luau client/Controllers/UnboxController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
